# CNN Inference on FPGA — MNIST Digit Recognition

Convolutional neural network trained in Python and deployed on an FPGA
for handwritten digit recognition. 98.53% test accuracy with int8 quantization.

![demo](docs/demo.png)

## What it does
Trains a CNN on the MNIST dataset, quantizes the weights to int8, exports them
to a hardware-compatible format, and runs inference directly on the FPGA fabric.

## Stack
Python (TensorFlow, NumPy) · VHDL · Quartus · ModelSim

## Results
| Metric | Value |
|---|---|
| Test accuracy | 98.53% |
| Quantization | int8 |

## Structure
- `training/` — model definition and training scripts
- `hdl/` — VHDL implementation
- `docs/` — RTL diagrams and waveform analysis

## Notes
Academic project — Universidad Militar Nueva Granada, 2025.
