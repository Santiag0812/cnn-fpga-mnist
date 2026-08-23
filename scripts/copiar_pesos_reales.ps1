# ================================================================
# Copia los pesos exportados desde el notebook hacia la carpeta mem
# del proyecto estructural de Quartus.
#
# AJUSTA estas dos rutas si tu carpeta está en otro lugar.
# ================================================================

$src = "C:\Users\santi\OneDrive\Escritorio\ADELANTO PARCIAL FINAL IA EN HW\export_hardware_cnn_mnist\pesos_por_capa"
$dst = "C:\Users\santi\Downloads\CNN_MNIST_ESTRUCTURAL_FPGA\mem"

New-Item -ItemType Directory -Force -Path $dst | Out-Null

Copy-Item "$src\conv1_3x3_8\conv1_3x3_8_kernel_int8.hex" "$dst\conv1_kernel_int8.hex" -Force
Copy-Item "$src\conv1_3x3_8\conv1_3x3_8_bias_int8.hex"   "$dst\conv1_bias_int8.hex"   -Force

Copy-Item "$src\conv2_3x3_16\conv2_3x3_16_kernel_int8.hex" "$dst\conv2_kernel_int8.hex" -Force
Copy-Item "$src\conv2_3x3_16\conv2_3x3_16_bias_int8.hex"   "$dst\conv2_bias_int8.hex"   -Force

Copy-Item "$src\dense1_32\dense1_32_kernel_int8.hex" "$dst\dense1_kernel_int8.hex" -Force
Copy-Item "$src\dense1_32\dense1_32_bias_int8.hex"   "$dst\dense1_bias_int8.hex"   -Force

Copy-Item "$src\logits_10\logits_10_kernel_int8.hex" "$dst\logits_kernel_int8.hex" -Force
Copy-Item "$src\logits_10\logits_10_bias_int8.hex"   "$dst\logits_bias_int8.hex"   -Force

Write-Host "Pesos copiados en: $dst"
Write-Host "Lineas esperadas:"
Write-Host "conv1_kernel:" (Get-Content "$dst\conv1_kernel_int8.hex").Count "debe ser 72"
Write-Host "conv1_bias  :" (Get-Content "$dst\conv1_bias_int8.hex").Count "debe ser 8"
Write-Host "conv2_kernel:" (Get-Content "$dst\conv2_kernel_int8.hex").Count "debe ser 1152"
Write-Host "conv2_bias  :" (Get-Content "$dst\conv2_bias_int8.hex").Count "debe ser 16"
Write-Host "dense1_kernel:" (Get-Content "$dst\dense1_kernel_int8.hex").Count "debe ser 12800"
Write-Host "dense1_bias  :" (Get-Content "$dst\dense1_bias_int8.hex").Count "debe ser 32"
Write-Host "logits_kernel:" (Get-Content "$dst\logits_kernel_int8.hex").Count "debe ser 320"
Write-Host "logits_bias  :" (Get-Content "$dst\logits_bias_int8.hex").Count "debe ser 10"
