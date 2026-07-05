# BLE Digital Transmitter

## Project Description

This repository contains the complete design, implementation, and documentation of a **Bluetooth Low Energy (BLE) Digital Transmitter**. The project covers the full development flow of the transmitter — from system-level architecture and modeling, through RTL implementation and verification, to supporting research, references, and academic documentation.

The goal of this project is to design a digital BLE transmitter that handles the baseband and link-layer processing, interfaces correctly with the analog front-end (RF/PHY), and is verified through simulation before implementation. The repository is organized so that each stage of the design process — architecture, interfaces, modeling, implementation, and verification — has its own dedicated folder.

---

## Repository Structure

### 📁 Architecture
This folder contains the high-level architectural design of the transmitter, including:
- **System Architecture & Block Diagram** – the overall structure of the digital transmitter, showing the main functional blocks (e.g., baseband processing, modulation, control, and interfaces) and how data flows between them.
- **Control Unit Architecture & FSM** – the design of the control unit responsible for managing the transmitter's operation, including the Finite State Machine (FSM) diagrams and state transition logic that govern the transmit sequence.

### 📁 Interfaces
This folder documents all the interfaces used in the design, including:
- **Link Layer / PHY Interface** – specification of how the digital link layer communicates with the physical layer (PHY), including signal definitions, timing, and handshaking.
- **Analog-to-Digital Interface** – specification of the interface between the digital transmitter and the analog front-end (e.g., DAC control signals, timing, and data format).

### 📁 Papers
Reference research papers and technical articles related to BLE, digital transmitter design, RF/PHY interfacing, and related topics used to support the design decisions in this project.

### 📁 Presentations
Slide decks and presentation materials summarizing the project's progress, design methodology, and results — used for project reviews, milestones, or academic presentations.

### 📁 RTL Implementation
This folder contains the actual hardware description language (HDL) source code (SystemVerilog/Verilog) implementing the digital transmitter. Rather than being one large flat design, the RTL is broken down into a **separate subfolder for each functional block** of the transmitter, plus a subfolder that integrates everything together. This makes it easy to develop, debug, and reuse each block independently before combining them into the full system. The subfolders are:

- **ADPLL Integration** – RTL that integrates all the sub-blocks belonging to the All-Digital Phase-Locked Loop (ADPLL) loop (e.g., TDC, Loop Filter, DCO, Sigma-Delta) into a single, complete ADPLL module.
- **Control Unit** – RTL for the control logic/FSM that sequences and coordinates the operation of the transmitter (e.g., enabling blocks, managing transmit states, handling handshaking).
- **DCO (Digitally Controlled Oscillator)** – RTL implementation of the oscillator that generates the RF carrier frequency, digitally tuned instead of using an analog VCO.
- **Gaussian Filter** – RTL implementation of the Gaussian pulse-shaping filter applied to the data before modulation, as required for GFSK modulation used in BLE.
- **IIR Filter** – RTL implementation of the Infinite Impulse Response filter used somewhere in the signal processing/data path (e.g., smoothing or shaping signals within the loop).
- **LMS (Least Mean Squares)** – RTL implementation of the adaptive LMS algorithm, typically used for calibration or gain normalization (e.g., DCO gain estimation) within the ADPLL.
- **Loop Filter** – RTL implementation of the digital loop filter of the ADPLL, which processes the phase/frequency error and generates the tuning word for the DCO.
- **NRZ (Non-Return-to-Zero)** – RTL implementation of the NRZ encoding block used to prepare the raw bitstream data before further processing/modulation.
- **Outside ADPLL Integration** – RTL that integrates all the blocks that sit *outside* the ADPLL loop (e.g., NRZ, Gaussian Filter, Upsampler) into a single module, separate from the ADPLL core.
- **Sigma Delta** – RTL implementation of the Sigma-Delta modulator, typically used for fractional-N division/dithering within the ADPLL.
- **System Integration** – The top-level RTL that connects and integrates *all* the individual blocks above (both inside and outside the ADPLL) into the complete, final digital transmitter design.
- **TDC (Time-to-Digital Converter)** – RTL implementation of the TDC, which measures the phase error between the reference clock and the DCO output as part of the ADPLL.
- **Upsampler** – RTL implementation of the upsampling block, used to increase the data rate/sample rate to match the required processing or output rate.

### 📁 Simulation
This folder mirrors the structure of the RTL Implementation folder: it contains a **separate subfolder for each block** (ADPLL Integration, Control Unit, DCO, Gaussian Filter, IIR Filter, LMS, Loop Filter, NRZ, Outside ADPLL Integration, Sigma Delta, TDC, Upsampler) holding the testbenches, simulation scripts, and results used to verify that specific block in isolation. In addition, there is a **System Integration** subfolder containing the testbenches and simulation results used to verify the complete, fully integrated transmitter design once all blocks are combined.

### 📁 System Modeling
This folder contains high-level behavioral/algorithmic models (e.g., MATLAB/Python/Simulink) of the transmitter, used to validate design concepts before committing to RTL. Just like the RTL Implementation and Simulation folders, it is organized into a **separate subfolder per block** (ADPLL Integration, Control Unit, DCO, Gaussian Filter, IIR Filter, LMS, Loop Filter, NRZ, Outside ADPLL Integration, Sigma Delta, TDC, Upsampler), allowing each block's behavior (e.g., modulation, filtering, oscillator behavior) to be modeled and validated independently. A **System Integration** subfolder contains the combined high-level model of the entire transmitter, used to validate overall system-level performance (e.g., end-to-end modulation accuracy, loop stability, timing) before RTL implementation begins.

### 📁 Text Books
Reference textbooks and course material related to BLE, wireless communication, digital design, and RF systems used throughout the project.

### 📁 Thesis
The full thesis document (or drafts of it) associated with this project, consolidating the motivation, design, implementation, results, and conclusions of the work.

---

## Notes
This repository is a work in progress. Folder contents will continue to be updated as the design, verification, and documentation evolve.
