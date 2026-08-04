#include <ros.h>
#include <std_msgs/Float32.h>
#include <BasicLinearAlgebra.h>

using namespace BLA;

ros::NodeHandle nh;

// RS485 and encoder setup
#define RE_DE_PIN_R 2
#define RE_DE_PIN_L 9
byte buffer[9];
unsigned int bufferIndexR = 0, bufferIndexL = 0;
int encoderPositionR = 0, angleValueR = 0;
int encoderPositionL = 0, angleValueL = 0;

// Motor control
int rpwm = 23, lpwm = 22, ren = 21, len = 20;
const int minPWM = 750;
const int maxPWM = 3000;

// Control variables
double targetAngle = 0;
double rightAngle = 0, leftAngle = 0, newAngle = 0;
double previousError = 0, controlSignal = 0;

// ROS message and publisher
std_msgs::Float32 msg;
ros::Publisher curra("/yaw_displacement", &msg);

// MPC controller parameters
const int hz = 10;           // Prediction horizon
const double Ts = 0.05;      // Sample time
double x_state[4] = {0, 0, 0, 0}; // State: [y_dot, psi, psi_dot, Y]

// Car model parameters
const double m = 180;     // Mass
const double Iz = 1500;   // Moment of inertia
const double Caf = 616;   // Front cornering stiffness
const double Car = 3080;  // Rear cornering stiffness
const double lf = 0.837;  // Distance from CG to front axle
const double lr = 0.638;  // Distance from CG to rear axle
const double x_dot = 2;   // Longitudinal velocity

// MPC Matrices
// System dynamics matrices
Matrix<4, 4> A;           // System dynamics matrix
Matrix<4, 1> B;           // Control input matrix
Matrix<2, 4> C;           // Output matrix
// Cost matrices
Matrix<2, 2> Q;           // State cost matrix
Matrix<2, 2> S;           // Terminal state cost matrix 
Matrix<1, 1> R;           // Control cost matrix
// MPC computation matrices
Matrix<4*hz, 4> Adc;      // Prediction matrix A
Matrix<4*hz, hz> Cdb;     // Prediction matrix B
Matrix<hz, hz> Hdb;       // Hessian matrix
Matrix<hz, 4+1> Fdbt;     // Gradient matrix

// Function prototypes
void processBufferR(byte *buf);
void processBufferL(byte *buf);
void angleConversionR();
void angleConversionL();
void mpcMatrixInit();
void mpcSetupPredictionMatrices();
double mpcSteeringControl(double error, double delta_error);

// Initialize the state space matrices for MPC
void mpcMatrixInit() {
  // System dynamics model for lateral vehicle motion
  // Continuous time state-space model
  
  // Computing the coefficients used in state-space matrices
  double A1 = -(2*Caf+2*Car)/(m*x_dot);
  double A2 = -x_dot-(2*Caf*lf-2*Car*lr)/(m*x_dot);
  double A3 = -(2*lf*Caf-2*lr*Car)/(Iz*x_dot);
  double A4 = -(2*lf*lf*Caf+2*lr*lr*Car)/(Iz*x_dot);
  
  // Continuous time matrices
  // x = [y_dot, psi, psi_dot, Y]
  // A matrix
  A.Fill(0);
  A(0,0) = A1;   // -(2*Caf+2*Car)/(m*x_dot)
  A(0,2) = A2;   // -x_dot-(2*Caf*lf-2*Car*lr)/(m*x_dot)
  A(1,2) = 1.0;  // psi_dot to psi
  A(2,0) = A3;   // -(2*lf*Caf-2*lr*Car)/(Iz*x_dot)
  A(2,2) = A4;   // -(2*lf*lf*Caf+2*lr*lr*Car)/(Iz*x_dot)
  A(3,0) = 1.0;  // y_dot contribution to Y
  A(3,1) = x_dot; // psi contribution to Y (simplified from sin(psi)*x_dot)
  
  // B matrix
  B.Fill(0);
  B(0,0) = 2*Caf/m;
  B(2,0) = 2*lf*Caf/Iz;
  
  // C matrix (outputs: psi and Y)
  C.Fill(0);
  C(0,1) = 1.0;  // Output 1: psi
  C(1,3) = 1.0;  // Output 2: Y
  
  // Discretize the system using Forward Euler
  // Ad = I + Ts*A, Bd = Ts*B
  for (int i = 0; i < 4; i++) {
    for (int j = 0; j < 4; j++) {
      if (i == j) {
        A(i,j) = 1.0 + Ts * A(i,j);
      } else {
        A(i,j) = Ts * A(i,j);
      }
    }
    B(i,0) = Ts * B(i,0);
  }
  
  // Cost matrices setup
  // Q for tracking error, S for terminal cost, R for control effort
  Q.Fill(0);
  Q(0,0) = 1.0;  // Weight for psi error
  Q(1,1) = 1.0;  // Weight for Y error
  
  S.Fill(0);
  S(0,0) = 5.0;  // Terminal weight for psi error
  S(1,1) = 5.0;  // Terminal weight for Y error
  
  R(0,0) = 0.1;  // Control effort weight
  
  // Setup prediction matrices for the MPC controller
  mpcSetupPredictionMatrices();
}

// Setup prediction matrices for MPC
void mpcSetupPredictionMatrices() {
  // Setup augmented state-space matrices
  Matrix<5, 5> A_aug;
  Matrix<5, 1> B_aug;
  Matrix<2, 5> C_aug;
  
  // Create augmented matrices for incremental control
  A_aug.Fill(0);
  B_aug.Fill(0);
  C_aug.Fill(0);
  
  // A_aug = [A Bd; 0 I]
  for (int i = 0; i < 4; i++) {
    for (int j = 0; j < 4; j++) {
      A_aug(i,j) = A(i,j);
    }
    A_aug(i,4) = B(i,0);
  }
  A_aug(4,4) = 1.0;
  
  // B_aug = [Bd; I]
  for (int i = 0; i < 4; i++) {
    B_aug(i,0) = B(i,0);
  }
  B_aug(4,0) = 1.0;
  
  // C_aug = [C 0]
  for (int i = 0; i < 2; i++) {
    for (int j = 0; j < 4; j++) {
      C_aug(i,j) = C(i,j);
    }
  }
  
  // Initialize prediction matrices
  Adc.Fill(0);
  Cdb.Fill(0);
  
  // Calculate prediction matrices
  // Compute powers of A_aug for prediction
  Matrix<5, 5> A_pow = A_aug;
  
  // Fill Adc with powers of A_aug
  for (int i = 0; i < hz; i++) {
    // Copy the current power of A_aug to the appropriate block in Adc
    for (int j = 0; j < 4; j++) {
      for (int k = 0; k < 4; k++) {
        Adc(i*4+j, k) = A_pow(j, k);
      }
    }
    
    if (i < hz-1) {
      // Calculate the next power: A_pow = A_pow * A_aug
      Matrix<5, 5> A_pow_next;
      A_pow_next.Fill(0);
      
      for (int j = 0; j < 5; j++) {
        for (int k = 0; k < 5; k++) {
          for (int l = 0; l < 5; l++) {
            A_pow_next(j, k) += A_pow(j, l) * A_aug(l, k);
          }
        }
      }
      A_pow = A_pow_next;
    }
  }
  
  // Fill Cdb matrix (control influence over prediction horizon)
  for (int i = 0; i < hz; i++) {
    for (int j = 0; j <= i; j++) {
      // Calculate A_aug^(i-j) * B_aug
      Matrix<5, 5> A_temp;
      A_temp.Fill(0);
      
      // Set A_temp to identity initially
      for (int k = 0; k < 5; k++) {
        A_temp(k, k) = 1.0;
      }
      
      // Calculate A_temp = A_aug^(i-j)
      for (int k = 0; k < i-j; k++) {
        Matrix<5, 5> A_temp_next;
        A_temp_next.Fill(0);
        
        for (int l = 0; l < 5; l++) {
          for (int m = 0; m < 5; m++) {
            for (int n = 0; n < 5; n++) {
              A_temp_next(l, m) += A_temp(l, n) * A_aug(n, m);
            }
          }
        }
        A_temp = A_temp_next;
      }
      
      // Calculate A_temp * B_aug
      Matrix<5, 1> B_temp;
      B_temp.Fill(0);
      
      for (int k = 0; k < 5; k++) {
        for (int l = 0; l < 5; l++) {
          B_temp(k, 0) += A_temp(k, l) * B_aug(l, 0);
        }
      }
      
      // Copy the result to Cdb
      for (int k = 0; k < 4; k++) {
        Cdb(i*4+k, j) = B_temp(k, 0);
      }
    }
  }
  
  // Calculate Hdb and Fdbt matrices for the optimization problem
  Hdb.Fill(0);
  Fdbt.Fill(0);
  
  // Compute Hdb = Cdb^T * Q_bar * Cdb + R_bar
  // Simplified version - we'll compute just the main diagonal
  for (int i = 0; i < hz; i++) {
    // Add R contribution
    Hdb(i, i) = R(0, 0);
    
    // Add Q contribution
    for (int j = 0; j < hz; j++) {
      for (int k = 0; k < 4; k++) {
        if (k == 1) {  // psi state
          Hdb(i, j) += Cdb(i*4+k, i) * Q(0, 0) * Cdb(j*4+k, j);
        }
        else if (k == 3) {  // Y state
          Hdb(i, j) += Cdb(i*4+k, i) * Q(1, 1) * Cdb(j*4+k, j);
        }
      }
    }
  }
  
  // Simplify the calculation of Fdbt for the Arduino
  // This is a gradient matrix that gives the optimal control input
  for (int i = 0; i < hz; i++) {
    for (int j = 0; j < 4; j++) {
      // State cost contribution
      if (j == 1) {  // psi state
        Fdbt(i, j) = -Cdb(j, i) * Q(0, 0);
      }
      else if (j == 3) {  // Y state
        Fdbt(i, j) = -Cdb(j, i) * Q(1, 1);
      }
    }
    // Last column is for the current control input
    Fdbt(i, 4) = 0;
  }
}

// MPC steering controller 
double mpcSteeringControl(double error, double delta_error) {
  // Update the state vector based on the current error
  // x_state = [y_dot, psi, psi_dot, Y]
  // For simplicity, we'll just update psi (angle error) and Y position
  x_state[1] = error;              // psi (steering angle error)
  x_state[2] = delta_error / Ts;   // psi_dot (rate of change)
  x_state[3] = error * 0.1;        // Y (lateral position error - approximated)
  
  // Create augmented current state with the last control input
  Matrix<5, 1> x_aug_t;
  for (int i = 0; i < 4; i++) {
    x_aug_t(i, 0) = x_state[i];
  }
  x_aug_t(4, 0) = controlSignal - 1500;  // Convert from PWM to steering offset
  
  // Reference vector (target state)
  Matrix<hz*2, 1> r;
  r.Fill(0);  // Target is zero error in psi and Y
  
  // Calculate the optimization problem terms
  Matrix<hz, 1> ft;
  ft.Fill(0);
  
  // ft = [x_aug_t^T, r^T] * Fdbt
  for (int i = 0; i < hz; i++) {
    for (int j = 0; j < 5; j++) {
      ft(i, 0) += x_aug_t(j, 0) * Fdbt(i, j);
    }
    // Add reference contribution (zero in this case)
  }
  
  // Calculate optimal control input: du = -inv(Hdb) * ft
  // For horizon=1, we can directly solve
  Matrix<hz, 1> du;
  
  if (hz == 1) {
    du(0, 0) = -ft(0, 0) / Hdb(0, 0);
  } else {
    // For larger horizons, we need to solve linear equations
    // Using a simple Gauss-Seidel method for approximate solution
    du.Fill(0);
    for (int iter = 0; iter < 5; iter++) {  // Limited iterations for real-time performance
      for (int i = 0; i < hz; i++) {
        double sum = 0;
        for (int j = 0; j < hz; j++) {
          if (i != j) {
            sum += Hdb(i, j) * du(j, 0);
          }
        }
        du(i, 0) = -(ft(i, 0) + sum) / Hdb(i, i);
      }
    }
  }
  
  // We only use the first control action (receding horizon principle)
  double control_adjustment = du(0, 0);
  
  // Scale the control output to match the original controller's range
  double steer_max = 500.0;
  return control_adjustment * steer_max;
}

// ROS message callback
void messageCallback(const std_msgs::Float32& received_msg) {
  targetAngle = received_msg.data;
}

ros::Subscriber<std_msgs::Float32> sub("/steering_angle", &messageCallback);

// Function to check if the steerer is centered
bool isSteeringCentered() {
    const double tolerance = 0.5; // Tolerance in degrees
    return (abs(newAngle) < tolerance);
}

void setup() {
  nh.initNode();
  nh.advertise(curra);
  nh.subscribe(sub);
  Serial.print(controlSignal);
  Serial.begin(19200);
  Serial1.begin(19200);
  Serial2.begin(19200);
  pinMode(23, OUTPUT);
  pinMode(22, OUTPUT);
  pinMode(ren, OUTPUT);
  pinMode(len, OUTPUT);
  pinMode(RE_DE_PIN_R, OUTPUT);
  pinMode(RE_DE_PIN_L, OUTPUT);
  digitalWrite(RE_DE_PIN_R, LOW);
  digitalWrite(RE_DE_PIN_L, LOW);
  analogWriteResolution(12);
  
  // Initialize MPC matrices
  mpcMatrixInit();

  // Make sure the steer is centered before starting control
  if (!isSteeringCentered()) {
    Serial.println("Steering is not centered.");
    while (!isSteeringCentered()) {
    // Wait until the steer is centered
    delay(50);
    }
  }
}

void loop() {
  digitalWrite(ren, HIGH);
  digitalWrite(len, HIGH);
  digitalWrite(RE_DE_PIN_R, LOW);
  digitalWrite(RE_DE_PIN_L, LOW);
  
  while (Serial1.available()) {
    byte incomingByteR = Serial1.read();
    buffer[bufferIndexR++] = incomingByteR;  
    if (bufferIndexR >= sizeof(buffer)) {
      processBufferR(buffer);
      bufferIndexR = 0;
    }
  }
  while (Serial2.available()) {
    byte incomingByteL = Serial2.read();
    buffer[bufferIndexL++] = incomingByteL;  
    if (bufferIndexL >= sizeof(buffer)) {
      processBufferL(buffer);
      bufferIndexL = 0;
    }
  }

  newAngle = 49 - rightAngle;
  Serial.print(" Left: "); Serial.print(leftAngle);
  Serial.print("  Right: "); Serial.print(rightAngle);
  Serial.print("  New: "); Serial.println(newAngle);
  double error = targetAngle - newAngle;
  double delta_error = error - previousError;
  previousError = error;

  // MPC control calculation
  double pwm_adjust = mpcSteeringControl(error, delta_error);
  controlSignal = 1500 + pwm_adjust; // Neutral at 1500
  
  // Motor control logic 
  controlSignal = constrain(controlSignal, minPWM, maxPWM);
  if (error > 1.0) { 
    analogWrite(rpwm, controlSignal);
    analogWrite(lpwm, 0);
  } else if (error < - 1.0) { 
    analogWrite(rpwm, 0);
    analogWrite(lpwm, controlSignal);
  } else {
    analogWrite(rpwm, 0);
    analogWrite(lpwm, 0);
  }

  // Publish data
  msg.data = newAngle;
  curra.publish(&msg);
  nh.spinOnce();
  delay(50);
}

// Encoder processing functions 
void processBufferR(byte *buf) {
  if (buf[0] == 171 && buf[1] == 205 && buf[2] == 5) {
    encoderPositionR = buf[3];
    angleValueR = buf[4];
    if (buf[5] == 0 && buf[6] == 255) {
      angleConversionR();
    }
  }
}

void processBufferL(byte *buf) {
  if (buf[0] == 171 && buf[1] == 205 && buf[2] == 5) {
    encoderPositionL = buf[3];
    angleValueL = buf[4];
    if (buf[5] == 0 && buf[6] == 255) {
      angleConversionL();
    }
  }
}

void angleConversionR() {
  if (angleValueR < 0) angleValueR = 0; // Ensure the value is within the 0-255 range
  if (angleValueR > 255) angleValueR = 255;

  switch (encoderPositionR) {
    case 0: rightAngle = (angleValueR / 255.0f) * 22.5f; break;
    case 1: rightAngle = (angleValueR / 255.0f) * (45.0f - 22.6f)   + 22.6f; break;
    case 2: rightAngle = (angleValueR / 255.0f) * (67.5f - 45.1f)   + 45.1f; break;
    case 3: rightAngle = (angleValueR / 255.0f) * (90.0f - 67.6f)   + 67.6f; break;
    case 4: rightAngle = (angleValueR / 255.0f) * (112.5f - 90.1f)  + 90.1f; break;
    case 5: rightAngle = (angleValueR / 255.0f) * (135.0f - 112.6f) + 112.6f;break;
    case 6: rightAngle = (angleValueR / 255.0f) * (157.5f - 135.1f) + 135.1f;break;
    case 7: rightAngle = (angleValueR / 255.0f) * (180.0f - 157.6f) + 157.6f;break;
    case 8: rightAngle = (angleValueR / 255.0f) * (202.5f - 180.1f) + 180.1f;break;                                                        
    case 9: rightAngle = (angleValueR / 255.0f) * (225.0f - 202.6f) + 202.6f;break;
    case 10:rightAngle = (angleValueR / 255.0f) * (247.5f - 225.1f) + 225.1f;break;
    case 11:rightAngle = (angleValueR / 255.0f) * (270.0f - 247.6f) + 247.6f;break;
    case 12:rightAngle = (angleValueR / 255.0f) * (292.5f - 270.1f) + 270.1f;break;
    case 13:rightAngle = (angleValueR / 255.0f) * (315.0f - 292.6f) + 292.6f;break;
    case 14:rightAngle = (angleValueR / 255.0f) * (337.5f - 315.1f) + 315.1f;break;
    case 15:rightAngle = (angleValueR / 255.0f) * (360.0f - 337.6f) + 337.6f;break;
    default:rightAngle = 0;break;
  }
}

void angleConversionL() {
  if (angleValueL < 0) angleValueL = 0; // Ensure the value is within the 0-255 range
  if (angleValueL > 255) angleValueL = 255;

  switch (encoderPositionL) {
    case 0: leftAngle = (angleValueL / 255.0f) * 22.5f; break;
    case 1: leftAngle = (angleValueL / 255.0f) * (45.0f - 22.6f)   + 22.6f; break;
    case 2: leftAngle = (angleValueL / 255.0f) * (67.5f - 45.1f)   + 45.1f; break;
    case 3: leftAngle = (angleValueL / 255.0f) * (90.0f - 67.6f)   + 67.6f; break;
    case 4: leftAngle = (angleValueL / 255.0f) * (112.5f - 90.1f)  + 90.1f; break;
    case 5: leftAngle = (angleValueL / 255.0f) * (135.0f - 112.6f) + 112.6f;break;
    case 6: leftAngle = (angleValueL / 255.0f) * (157.5f - 135.1f) + 135.1f;break;
    case 7: leftAngle = (angleValueL / 255.0f) * (180.0f - 157.6f) + 157.6f;break;
    case 8: leftAngle = (angleValueL / 255.0f) * (202.5f - 180.1f) + 180.1f;break;
    case 9: leftAngle = (angleValueL / 255.0f) * (225.0f - 202.6f) + 202.6f;break;
    case 10:leftAngle = (angleValueL / 255.0f) * (247.5f - 225.1f) + 225.1f;break;
    case 11:leftAngle = (angleValueL / 255.0f) * (270.0f - 247.6f) + 247.6f;break;
    case 12:leftAngle = (angleValueL / 255.0f) * (292.5f - 270.1f) + 270.1f;break;
    case 13:leftAngle = (angleValueL / 255.0f) * (315.0f - 292.6f) + 292.6f;break;
    case 14:leftAngle = (angleValueL / 255.0f) * (337.5f - 315.1f) + 315.1f;break;
    case 15:leftAngle = (angleValueL / 255.0f) * (360.0f - 337.6f) + 337.6f;break;
    default:leftAngle = 0;break;
  }
}