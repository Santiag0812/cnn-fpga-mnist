$dst = "C:\Users\santi\Downloads\CNN_MNIST_ESTRUCTURAL_FPGA\mem"
(Get-Content "$dst\conv1_kernel_int8.hex").Count
(Get-Content "$dst\conv1_bias_int8.hex").Count
(Get-Content "$dst\conv2_kernel_int8.hex").Count
(Get-Content "$dst\conv2_bias_int8.hex").Count
(Get-Content "$dst\dense1_kernel_int8.hex").Count
(Get-Content "$dst\dense1_bias_int8.hex").Count
(Get-Content "$dst\logits_kernel_int8.hex").Count
(Get-Content "$dst\logits_bias_int8.hex").Count
