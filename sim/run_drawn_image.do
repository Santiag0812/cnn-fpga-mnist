transcript on

cd {C:/Users/santi/OneDrive/Escritorio/CNN_MNIST_ESTRUCTURAL_FPGA/CNN_MNIST_ESTRUCTURAL_FPGA}

if {[file exists work]} {
    vdel -lib work -all
}

vlib work
vmap work work

vcom -2008 src/package_cnn.vhd
vcom -2008 src/mac_unit.vhd
vcom -2008 src/relu_unit.vhd
vcom -2008 src/maxpool2x2.vhd
vcom -2008 src/argmax10.vhd
vcom -2008 src/conv3x3_layer_struct.vhd
vcom -2008 src/maxpool_layer_struct.vhd
vcom -2008 src/dense_layer_struct.vhd
vcom -2008 src/controlador_cnn_struct.vhd
vcom -2008 src/cnn_top.vhd
vcom -2008 sim/tb_cnn_image_assert.vhd

vsim -voptargs=+acc work.tb_cnn_image_assert -gIMAGE_FILE="sim/data/drawn_digit.hex" -gEXPECTED_DIGIT=0 -gMAX_CYCLES=3000000

add wave -divider "CONTROL GENERAL"
add wave -radix binary   sim:/tb_cnn_image_assert/clk
add wave -radix binary   sim:/tb_cnn_image_assert/rst
add wave -radix binary   sim:/tb_cnn_image_assert/start
add wave -radix binary   sim:/tb_cnn_image_assert/done
add wave -radix unsigned sim:/tb_cnn_image_assert/digit_out
add wave -radix unsigned sim:/tb_cnn_image_assert/debug_state

add wave -divider "CARGA DE IMAGEN"
add wave -radix binary   sim:/tb_cnn_image_assert/img_we
add wave -radix unsigned sim:/tb_cnn_image_assert/img_addr
add wave -radix signed   sim:/tb_cnn_image_assert/img_din

add wave -divider "CONTROL DE CAPAS"
add wave -radix binary sim:/tb_cnn_image_assert/dut/c1_start
add wave -radix binary sim:/tb_cnn_image_assert/dut/c1_done
add wave -radix binary sim:/tb_cnn_image_assert/dut/p1_start
add wave -radix binary sim:/tb_cnn_image_assert/dut/p1_done
add wave -radix binary sim:/tb_cnn_image_assert/dut/c2_start
add wave -radix binary sim:/tb_cnn_image_assert/dut/c2_done
add wave -radix binary sim:/tb_cnn_image_assert/dut/p2_start
add wave -radix binary sim:/tb_cnn_image_assert/dut/p2_done
add wave -radix binary sim:/tb_cnn_image_assert/dut/d1_start
add wave -radix binary sim:/tb_cnn_image_assert/dut/d1_done
add wave -radix binary sim:/tb_cnn_image_assert/dut/lg_start
add wave -radix binary sim:/tb_cnn_image_assert/dut/lg_done

add wave -divider "LOGITS Y ARGMAX"
add wave -radix signed   sim:/tb_cnn_image_assert/dut/logits_local
add wave -radix unsigned sim:/tb_cnn_image_assert/dut/digit_int

run -all
