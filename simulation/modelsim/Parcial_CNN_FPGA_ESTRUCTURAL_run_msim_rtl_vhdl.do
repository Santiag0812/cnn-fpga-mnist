transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vcom -93 -work work {C:/Users/santi/OneDrive/Escritorio/CNN_MNIST_ESTRUCTURAL_FPGA/CNN_MNIST_ESTRUCTURAL_FPGA/src/package_cnn.vhd}
vcom -93 -work work {C:/Users/santi/OneDrive/Escritorio/CNN_MNIST_ESTRUCTURAL_FPGA/CNN_MNIST_ESTRUCTURAL_FPGA/src/mac_unit.vhd}
vcom -93 -work work {C:/Users/santi/OneDrive/Escritorio/CNN_MNIST_ESTRUCTURAL_FPGA/CNN_MNIST_ESTRUCTURAL_FPGA/src/relu_unit.vhd}
vcom -93 -work work {C:/Users/santi/OneDrive/Escritorio/CNN_MNIST_ESTRUCTURAL_FPGA/CNN_MNIST_ESTRUCTURAL_FPGA/src/maxpool2x2.vhd}
vcom -93 -work work {C:/Users/santi/OneDrive/Escritorio/CNN_MNIST_ESTRUCTURAL_FPGA/CNN_MNIST_ESTRUCTURAL_FPGA/src/argmax10.vhd}
vcom -93 -work work {C:/Users/santi/OneDrive/Escritorio/CNN_MNIST_ESTRUCTURAL_FPGA/CNN_MNIST_ESTRUCTURAL_FPGA/src/controlador_cnn_struct.vhd}
vcom -93 -work work {C:/Users/santi/OneDrive/Escritorio/CNN_MNIST_ESTRUCTURAL_FPGA/CNN_MNIST_ESTRUCTURAL_FPGA/src/conv3x3_layer_struct.vhd}
vcom -93 -work work {C:/Users/santi/OneDrive/Escritorio/CNN_MNIST_ESTRUCTURAL_FPGA/CNN_MNIST_ESTRUCTURAL_FPGA/src/maxpool_layer_struct.vhd}
vcom -93 -work work {C:/Users/santi/OneDrive/Escritorio/CNN_MNIST_ESTRUCTURAL_FPGA/CNN_MNIST_ESTRUCTURAL_FPGA/src/dense_layer_struct.vhd}
vcom -93 -work work {C:/Users/santi/OneDrive/Escritorio/CNN_MNIST_ESTRUCTURAL_FPGA/CNN_MNIST_ESTRUCTURAL_FPGA/src/cnn_top.vhd}

