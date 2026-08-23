# Ejecutar desde la raiz del proyecto CNN_MNIST_ESTRUCTURAL_FPGA
vlib work
vcom -2008 src/package_cnn.vhd
vcom -2008 src/mac_unit.vhd
vcom -2008 src/relu_unit.vhd
vcom -2008 src/maxpool2x2.vhd
vcom -2008 src/argmax10.vhd
vcom -2008 src/conv3x3_layer_struct.vhd
vcom -2008 src/maxpool_layer_struct.vhd
vcom -2008 src/dense_layer_struct.vhd
vcom -2008 src/cnn_top.vhd
vcom -2008 sim/tb_mac_assert.vhd
vcom -2008 sim/tb_argmax_assert.vhd
vcom -2008 sim/tb_conv1_assert.vhd

vsim work.tb_mac_assert
run 200 ns

vsim work.tb_argmax_assert
run 100 ns

vsim work.tb_conv1_assert
run 2 ms
