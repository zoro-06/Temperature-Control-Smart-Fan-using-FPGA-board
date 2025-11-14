# 🌡️ Temperature-Controlled Smart Fan (FPGA)

[cite_start]This project is an FPGA-based automatic fan speed control system implemented in Verilog HDL[cite: 9]. [cite_start]It dynamically regulates the speed of a 4-wire PWM fan to one of three modes (OFF, LOW, HIGH) based on ambient temperature readings from a PmodTMP2 digital sensor[cite: 4, 5, 6].

[cite_start]The system is built on a **Xilinx Artix-7 FPGA (Basys3 board)**[cite: 5]. [cite_start]It processes the temperature, generates a PWM signal to drive the fan via an IRLZ44N MOSFET, and monitors real-time fan RPM using tachometer feedback[cite: 5, 7]. [cite_start]The current temperature is displayed on the 7-segment display, and the active fan mode is shown on the on-board LEDs[cite: 8].

---

## 🚀 Features

* [cite_start]**Dynamic Speed Control:** Automatically adjusts fan speed to OFF, LOW, or HIGH based on set temperature thresholds[cite: 6, 29].
* [cite_start]**Digital Temperature Sensing:** Uses a PmodTMP2 sensor with an I²C master controller for accurate temperature acquisition[cite: 5].
* [cite_start]**PWM Actuation:** Generates a 2 kHz PWM signal to control the fan's speed via a logic-level MOSFET[cite: 7, 412].
* [cite_start]**Closed-Loop Feedback:** Implements a tachometer reader to measure the fan's actual RPM[cite: 7, 33].
* [cite_start]**Real-time Status Display:** Shows the current ambient temperature on the 7-segment display and the fan's speed mode on LEDs[cite: 8, 35].
* [cite_start]**Stable Operation:** A hysteresis-based control algorithm prevents rapid fan speed oscillations near the temperature thresholds[cite: 6].

---

## 🛠️ Hardware & Software Requirements

### Hardware
* [cite_start]**FPGA:** Digilent Basys3 (Xilinx Artix-7) [cite: 135]
* [cite_start]**Sensor:** PmodTMP2 (Digital Temperature Sensor) [cite: 136]
* [cite_start]**Fan:** 12V 4-wire PWM Desktop Cooling Fan [cite: 166, 168]
* [cite_start]**Driver:** IRLZ44N N-Channel MOSFET [cite: 160]
* [cite_start]**Power:** 12V DC Power Supply (for the fan) [cite: 171]
* **Components:**
    * [cite_start]4.5 kΩ Resistors (x2) [cite: 180, 181]
    * [cite_start]220 Ω Resistor [cite: 180]
    * [cite_start]1 kΩ Resistor [cite: 182]
    * Breadboard and Jumper Wires

### Software
* **Xilinx Vivado** (The project is built with Vivado, as indicated by the `.xpr` and `.runs` files in your repository).

---

## ▶️ How to Run the Project

1.  **Assemble the Hardware:**
    * [cite_start]Build the fan driver circuit on a breadboard using the IRLZ44N MOSFET, resistors, and 12V power supply as shown in the circuit diagram (Figure 1 of the report)[cite: 112].
    * [cite_start]Connect the PmodTMP2 sensor to the appropriate JA/JB Pmod headers on the Basys3 board[cite: 81, 86, 91, 95, 99].
    * [cite_start]Connect the fan's PWM and Tachometer pins to the circuit and the FPGA pins as specified in the constraints file (`const_fan_controller.xdc`)[cite: 870, 871].

2.  **Open the Project in Vivado:**
    * Clone or download your repository.
    * Open Xilinx Vivado.
    * Open the project by selecting the `temperature_fan.xpr` file.

3.  **Generate the Bitstream:**
    * In the Vivado Flow Navigator, click **Run Synthesis**, followed by **Run Implementation**.
    * Once implementation is complete, click **Generate Bitstream**.

4.  **Program the FPGA:**
    * Connect the Basys3 board to your computer using the micro-USB cable.
    * In Vivado, open the **Hardware Manager**.
    * Connect to the board (e.g., `Open Target` -> `Auto Connect`).
    * Click **Program Device** and select the generated bitstream file (located in `temperature_fan.runs/impl_1/`).

5.  **Run the System:**
    * Turn on the 12V DC power supply for the fan circuit.
    * The system is now live. [cite_start]The 7-segment display will show the current temperature from the PmodTMP2 sensor[cite: 37].
    * [cite_start]You can test the system by gently heating the sensor (e.g., with your finger or a warm object) and observing the LEDs change mode and the fan speed up[cite: 283].

---

## 📁 Project File Structure

* `temperature_fan.xpr`: The main Xilinx Vivado project file.
* [cite_start]`temperature_fan.srcs/`: Contains all Verilog source files (`top_module.v`, `i2c_master.v`, `pwm_generator.v`, `tachometer_reader.v`, etc.)[cite: 333, 449, 515, 728].
* [cite_start]`temperature_fan.srcs/constrs_1/`: Contains the constraints file (`const_fan_controller.xdc`) which maps the Verilog ports to the physical pins on the Basys3 board[cite: 827].
* `temperature_fan.runs/`: This directory stores the output files from the synthesis and implementation runs.
* `temperature_fan.cache/`: Vivado project cache.
* `README.md`: This file.

---

## 🎥 Demo Video

See the system in action!

[**<-- Link to your demo video here -->**]
