#include <Encoder.h>
#include <Adafruit_MCP4725.h>
#include <ros.h>
#include <std_msgs/Float32.h>

// ================= ENCODER & DAC =================
Encoder encLeft(2, 3);
Encoder encRight(5, 4);
Adafruit_MCP4725 dac;

// =============== ROS NODE ========================
ros::NodeHandle nh;

std_msgs::Float32 vel_msg;
ros::Publisher pub_vel("/velocity", &vel_msg);

// =============== TARGET SPEED ====================
// Target speed received from cbf_navigation_ros.py via /linear topic
// Unit: m/s (meters per second)
float targetSpeed = 0.0;

// Subscriber untuk target velocity
void linearCallback(const std_msgs::Float32 &msg) {
  targetSpeed = msg.data;
  Serial.print("TargetSpeed (ROS): ");
  Serial.println(targetSpeed, 3);
}
ros::Subscriber<std_msgs::Float32> sub_lin("/linear", &linearCallback);

// ================== BRAKE CONTROL =================
float brake_demand = 0.0;
bool brake_active = false;

// parameter blend
const float BRAKE_DEMAND_MAX = 1100.0;
const float THROTTLE_BLEND_START = 100.0; 
const float THROTTLE_BLEND_FULL = 580.0;

// Subscriber brake demand
void brakeCallback(const std_msgs::Float32 &msg) {
  brake_demand = msg.data;

  if (brake_demand > 50.0) brake_active = true;
  else {
    brake_active = false;
    brake_demand = 0.0;
  }
}
ros::Subscriber<std_msgs::Float32> sub_brake("/position", &brakeCallback);

// Kalkulasi blending factor (0 → throttle penuh, 1 → throttle = nol)
float calculateBlendingFactor(float b) {
  if (b <= THROTTLE_BLEND_START) return 0.0;
  if (b >= THROTTLE_BLEND_FULL) return 1.0;

  return (b - THROTTLE_BLEND_START) /
         (THROTTLE_BLEND_FULL - THROTTLE_BLEND_START);
}

// =============== PARAMETER FISIK =================
const float wheel_diameter = 0.36;
const float pulses_per_revolution = 400.0;
const float calibration_factor = 0.258962914;
const float faktor_skala = 3.3 / 4095.0;

// =============== PID PARAMETER ===================
float Kp = 1.8;
float Ki = 0.05;
float Kd = 0.01;

float integral = 0.0;
float prev_error = 0.0;

// =============== LUT =============================
// Look-Up Table: Voltage (V) → Speed (m/s)
// Used for feedforward control
const int LUT_SIZE = 16;
float lutVolt[LUT_SIZE]  = {0.0 ,1.3, 1.35, 1.4, 1.45, 1.5, 1.55, 1.6, 1.65, 1.7, 1.75, 1.8, 1.85, 1.9, 1.95, 2.0};
float lutSpeed[LUT_SIZE] = {0.0 ,0.0, 0.2277, 0.6436, 0.8102, 0.957, 1.2486, 1.4194, 2.0062, 2.0736, 2.3365, 2.662,
                            2.7706, 3.0342, 3.3868, 3.5764};

// =============== LOOP CONTROL ====================
unsigned long lastTime = 0;
const int LOOP_DT = 50; // 20 Hz

// =========== KONVERSI PULSE → SPEED ===============
// Returns speed in m/s
float measureSpeedMs() {
  static long lastL = encLeft.read();
  static long lastR = encRight.read();
  static unsigned long lastT = millis();

  long curL = encLeft.read();
  long curR = encRight.read();
  unsigned long curT = millis();

  long dp = ((curL - lastL) + (curR - lastR)) / 2;
  float dt = (curT - lastT) / 1000.0;

  lastL = curL;
  lastR = curR;
  lastT = curT;

  if (dt <= 0) return 0;

  float distance =
    ((float)dp / pulses_per_revolution) *
    (PI * wheel_diameter) *
    calibration_factor;

  return -(distance / dt);
}

// =========== INTERPOLASI LUT ======================
float getFeedforwardVolt(float target) {
  if (target <= lutSpeed[0]) return lutVolt[0];
  if (target >= lutSpeed[LUT_SIZE - 1]) return lutVolt[LUT_SIZE - 1];

  for (int i = 0; i < LUT_SIZE - 1; i++) {
    if (target >= lutSpeed[i] && target <= lutSpeed[i + 1]) {
      float t = (target - lutSpeed[i]) / (lutSpeed[i + 1] - lutSpeed[i]);
      return lutVolt[i] + t * (lutVolt[i + 1] - lutVolt[i]);
    }
  }
  return lutVolt[LUT_SIZE - 1];
}

// ============ PID KONTROL + BLENDING =============
float computePID(float e, float dt) {
  integral += e * dt;

  if (integral > 2.0) integral = 2.0;
  if (integral < -2.0) integral = -2.0;

  float derivative = (e - prev_error) / dt;
  prev_error = e;

  return Kp * e + Ki * integral + Kd * derivative;
}

// ===================== SETUP ======================
void setup() {
  Serial.begin(115200);

  dac.begin(0x60);
  dac.setVoltage(0, false);

  nh.initNode();
  nh.subscribe(sub_lin);
  nh.subscribe(sub_brake);
  nh.advertise(pub_vel);

  Serial.println("=== PID + LUT + BRAKE BLENDING (ROS) ===");
}

// ====================== LOOP ======================
void loop() {
  nh.spinOnce();

  unsigned long now = millis();
  if (now - lastTime < LOOP_DT) return;
  lastTime = now;

  float dt = LOOP_DT / 1000.0;

  // baca speed real (m/s)
  float speed = measureSpeedMs();

  // publish speed ke ROS (m/s)
  vel_msg.data = speed;
  pub_vel.publish(&vel_msg);

  // ======== Hitung blending throttle ========
  float blend_factor = calculateBlendingFactor(brake_demand);

  // target efektif saat rem
  float effective_target = targetSpeed * (1.0 - blend_factor);

  // error PID
  float error = effective_target - speed;

  // feedforward dari LUT
  float vff = getFeedforwardVolt(effective_target);

  // PID
  float vpid = computePID(error, dt);

  // total command
  float cmd = vff + vpid;
  if (cmd < 0) cmd = 0;
  if (cmd > 2.0) cmd = 2.0;

  int dacVal = (int)(cmd / faktor_skala);
  dac.setVoltage(dacVal, false);

  // PRINT SERIAL UNTUK MONITORING
  Serial.print("RawTgt:");
  Serial.print(targetSpeed, 3);
  Serial.print(" EffTgt:");
  Serial.print(effective_target, 3);
  Serial.print(" Speed:");
  Serial.print(speed, 3);
  Serial.print(" Brake:");
  Serial.print(brake_demand);
  Serial.print(" CMD:");
  Serial.println(cmd, 3);
}
