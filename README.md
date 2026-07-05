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
The actual hardware description language (HDL) source code (SystemVerilog/Verilog) implementing the digital transmitter design, including the control unit, FSM, and datapath modules described in the Architecture folder.

### 📁 Simulation
Testbenches, simulation scripts, and simulation results used to functionally verify the RTL implementation against the intended design behavior.

### 📁 System Modeling
High-level behavioral or algorithmic models of the transmitter (e.g., MATLAB/Python models) used to validate system-level concepts such as modulation, timing, and signal processing before RTL implementation.

### 📁 Text Books
Reference textbooks and course material related to BLE, wireless communication, digital design, and RF systems used throughout the project.

### 📁 Thesis
The full thesis document (or drafts of it) associated with this project, consolidating the motivation, design, implementation, results, and conclusions of the work.

---

## Notes
This repository is a work in progress. Folder contents will continue to be updated as the design, verification, and documentation evolve.
