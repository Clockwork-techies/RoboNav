# Rover
Electronic system level design of an autonomous rover controlled by an fpga based controller - (in VHDL).

This was a project done specifically to get a feel of actual full-stack electronic system design complete with both processing by fpga and sensor interfacing. Thus we wanted to choose a problem statement such that it includes:
                    1. Modules not just running in a forever loop, but getting triggered by other inter-modules events prompting to think of myriad triggering techniques, edge detection and control logic.
                    2. Implementation of sequential algorithms in hardware with deep, multi-state FSMs.
                    3. Communication such that it is not just bi-directional but also triggered as a part of an algorithm than just simple push button communication.
                    4. Original and still fun!

This made us to choose to implement a maze solving rover whose decisions are provided by the fpga and real life data procured by the rover itself. Such a system will need real time processing, changing data, synchronised bi-directional communication and multiple algorithms in need of common memory access. 

A detailed description of the whole system is presented as a report. 


Components used:
  0. Vivado and Arduino IDE
  1. Basys 3 
  2. BT2 PMOD (in fact any uart capable device)
  3. Hardware (rover):
       1. 2 x N20 motors with encoders
       2. 3 x HC-SR04 ultrasonic sensors
       3. TB66FNG motor driver
       4. Esp32
        
