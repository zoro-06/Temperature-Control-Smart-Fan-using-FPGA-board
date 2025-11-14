# 🌡️ Temperature-Controlled Smart Fan (FPGA)

This project is an FPGA-based automatic fan speed control system implemented in Verilog HDL. It dynamically regulates the speed of a 4-wire PWM fan to one of three modes (OFF, LOW, HIGH) based on ambient temperature readings from a PmodTMP2 digital sensor.

The system is built on a **Xilinx Artix-7 FPGA (Basys3 board)**. It processes the temperature, generates a PWM signal to drive the fan via an IRLZ44N MOSFET, and monitors real-time fan RPM using tachometer feedback. The current temperature is displayed on the 7-segment display, and the active fan mode is shown on the on-board LEDs.

---

## 🚀 Features

* **Dynamic Speed Control:** Automatically adjusts fan speed to OFF, LOW, or HIGH based on set temperature thresholds.
* **Digital Temperature Sensing:** Uses a PmodTMP2 sensor with an I²C master controller for accurate temperature acquisition.
* **PWM Actuation:** Generates a 2 kHz PWM signal to control the fan's speed via a logic-level MOSFET.
* **Closed-Loop Feedback:** Implements a tachometer reader to measure the fan's actual RPM.
* **Real-time Status Display:** Shows the current ambient temperature on the 7-segment display and the active fan's speed mode on LEDs.
* **Stable Operation:** A hysteresis-based control algorithm prevents rapid fan speed oscillations near the temperature thresholds.

---

## 🛠️ Hardware & Software Requirements

### Hardware
* **FPGA:** Digilent Basys3 (Xilinx Artix-7)
* **Sensor:** PmodTMP2 (Digital Temperature Sensor)
* **Fan:** 12V 4-wire PWM Desktop Cooling Fan
* **Driver:** IRLZ44N N-Channel MOSFET
* **Power:** 12V DC Power Supply (for the fan)
* **Components:**
    * 4.5 kΩ Resistors (x2)
    * 220 Ω Resistor
    * 1 kΩ Resistor
    * Breadboard and Jumper Wires

### Software
* **Xilinx Vivado** (The project is built with Vivado, as indicated by the `.xpr` and `.runs` files in your repository).

---

## ▶️ How to Run the Project

1.  **Assemble the Hardware:**
    * Build the fan driver circuit on a breadboard using the IRLZ44N MOSFET, resistors, and 12V power supply as shown in the circuit diagram (Figure 1 of the report).
    * Connect the PmodTMP2 sensor to the appropriate JA/JB Pmod headers on the Basys3 board.
    * Connect the fan's PWM and Tachometer pins to the circuit and the FPGA pins as specified in the constraints file (`const_fan_controller.xdc`).

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
    * The system is now live. The 7-segment display will show the current temperature from the PmodTMP2 sensor.
    * You can test the system by gently heating the sensor (e.g., with your finger or a warm object) and observing the LEDs change mode and the fan speed up.

---

## 📁 Project File Structure

* `temperature_fan.xpr`: The main Xilinx Vivado project file.
* `temperature_fan.srcs/`: Contains all Verilog source files (`top_module.v`, `i2c_master.v`, `pwm_generator.v`, `tachometer_reader.v`, etc.).
* `temperature_fan.srcs/constrs_1/`: Contains the constraints file (`const_fan_controller.xdc`) which maps the Verilog ports to the physical pins on the Basys3 board.
* `temperature_fan.runs/`: This directory stores the output files from the synthesis and implementation runs.
* `temperature_fan.cache/`: Vivado project cache.
* `README.md`: This file.

---

## 🎥 Demo Video

See the system in action!

[**<-- Link to your demo video here -->**]
