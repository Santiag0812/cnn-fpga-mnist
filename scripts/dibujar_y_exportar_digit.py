import tkinter as tk
from tkinter import messagebox
from pathlib import Path
from PIL import Image, ImageDraw, ImageTk
import numpy as np


# ============================================================
# RUTAS DEL PROYECTO
# ============================================================

PROJECT_ROOT = Path(__file__).resolve().parents[1]
SIM_DIR = PROJECT_ROOT / "sim"
DATA_DIR = SIM_DIR / "data"

DATA_DIR.mkdir(parents=True, exist_ok=True)

HEX_PATH = DATA_DIR / "drawn_digit.hex"
MIF_PATH = DATA_DIR / "drawn_digit.mif"
PREVIEW_PATH = DATA_DIR / "drawn_digit_preview.png"
IMG28_PATH = DATA_DIR / "drawn_digit_28x28.png"
EXPECTED_PATH = DATA_DIR / "drawn_expected.txt"
DO_PATH = SIM_DIR / "run_drawn_image.do"

CANVAS_SIZE = 300
FINAL_SIZE = 28
DIGIT_SIZE = 20


# ============================================================
# PREPROCESAMIENTO
# ============================================================

def preprocess_digit(pil_img, final_size=28, digit_size=20, threshold=20):
    """
    Convierte el dibujo al formato usado por MNIST:
    - fondo negro
    - número blanco
    - recorte del área útil
    - centrado
    - redimensionado a 28x28
    """

    img = pil_img.convert("L")
    arr = np.array(img)

    arr[arr < threshold] = 0

    ys, xs = np.where(arr > 0)

    if len(xs) == 0 or len(ys) == 0:
        return Image.new("L", (final_size, final_size), 0)

    x_min, x_max = xs.min(), xs.max()
    y_min, y_max = ys.min(), ys.max()

    cropped = Image.fromarray(arr).crop((x_min, y_min, x_max + 1, y_max + 1))

    w, h = cropped.size

    if w > h:
        new_w = digit_size
        new_h = max(1, int(h * digit_size / w))
    else:
        new_h = digit_size
        new_w = max(1, int(w * digit_size / h))

    cropped = cropped.resize((new_w, new_h), Image.Resampling.LANCZOS)

    canvas28 = Image.new("L", (final_size, final_size), 0)

    x_offset = (final_size - new_w) // 2
    y_offset = (final_size - new_h) // 2

    canvas28.paste(cropped, (x_offset, y_offset))

    return canvas28


def image28_to_int8_array(img28):
    """
    Convierte la imagen 28x28 a valores positivos de 8 bits.
    Rango usado: 0 a 127.
    """
    arr = np.array(img28).astype(np.float32)
    arr = np.round((arr / 255.0) * 127.0)
    arr = np.clip(arr, 0, 127).astype(np.uint8)
    return arr


def save_hex(arr28, path):
    """
    Guarda la imagen como archivo .hex.
    El testbench de ModelSim lee este archivo.
    """
    flat = arr28.flatten()

    with open(path, "w", encoding="utf-8") as f:
        for value in flat:
            f.write(f"{int(value):02X}\n")


def save_mif(arr28, path):
    """
    Guarda la imagen como archivo .mif.
    Este archivo sirve como evidencia para memorias tipo Quartus.
    """
    flat = arr28.flatten()

    with open(path, "w", encoding="utf-8") as f:
        f.write("WIDTH=8;\n")
        f.write("DEPTH=784;\n\n")
        f.write("ADDRESS_RADIX=UNS;\n")
        f.write("DATA_RADIX=HEX;\n\n")
        f.write("CONTENT BEGIN\n")

        for i, value in enumerate(flat):
            f.write(f"    {i} : {int(value):02X};\n")

        f.write("END;\n")


def write_modelsim_do(project_root, expected_digit):
    """
    Genera el archivo .do para correr directamente en ModelSim.
    """
    project_path = str(project_root).replace("\\", "/")

    content = f"""transcript on

cd {{{project_path}}}

if {{[file exists work]}} {{
    vdel -lib work -all
}}

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

vsim -voptargs=+acc work.tb_cnn_image_assert -gIMAGE_FILE="sim/data/drawn_digit.hex" -gEXPECTED_DIGIT={expected_digit} -gMAX_CYCLES=3000000

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
"""

    with open(DO_PATH, "w", encoding="utf-8") as f:
        f.write(content)


# ============================================================
# INTERFAZ GRÁFICA
# ============================================================

class DigitExporterApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Exportador de dígitos MNIST para ModelSim / FPGA")
        self.root.geometry("920x560")
        self.root.resizable(False, False)
        self.root.configure(bg="#eef2f7")

        self.last_x = None
        self.last_y = None

        self.image = Image.new("L", (CANVAS_SIZE, CANVAS_SIZE), 0)
        self.draw = ImageDraw.Draw(self.image)

        self.build_ui()
        self.update_preview()

    def build_ui(self):
        header = tk.Frame(self.root, bg="#1f3b57", height=70)
        header.pack(fill="x")

        title = tk.Label(
            header,
            text="Dibujar número y exportar para simulación FPGA",
            font=("Arial", 20, "bold"),
            fg="white",
            bg="#1f3b57"
        )
        title.pack(pady=18)

        body = tk.Frame(self.root, bg="#eef2f7")
        body.pack(fill="both", expand=True, padx=28, pady=22)

        left_card = tk.Frame(body, bg="white", bd=1, relief="solid")
        left_card.grid(row=0, column=0, padx=(0, 25), pady=0)

        tk.Label(
            left_card,
            text="Área de dibujo",
            font=("Arial", 14, "bold"),
            fg="#1f3b57",
            bg="white"
        ).pack(pady=(14, 8))

        self.canvas = tk.Canvas(
            left_card,
            width=CANVAS_SIZE,
            height=CANVAS_SIZE,
            bg="black",
            cursor="cross",
            highlightthickness=0
        )
        self.canvas.pack(padx=18, pady=(0, 18))

        self.canvas.bind("<Button-1>", self.start_draw)
        self.canvas.bind("<B1-Motion>", self.paint)
        self.canvas.bind("<ButtonRelease-1>", self.stop_draw)

        right_card = tk.Frame(body, bg="white", bd=1, relief="solid", width=420, height=360)
        right_card.grid(row=0, column=1, pady=0)
        right_card.grid_propagate(False)

        tk.Label(
            right_card,
            text="Imagen procesada 28×28",
            font=("Arial", 14, "bold"),
            fg="#1f3b57",
            bg="white"
        ).pack(pady=(16, 6))

        self.preview_label = tk.Label(right_card, bg="white")
        self.preview_label.pack(pady=4)

        form_frame = tk.Frame(right_card, bg="white")
        form_frame.pack(pady=10)

        tk.Label(
            form_frame,
            text="Etiqueta esperada:",
            font=("Arial", 12),
            fg="#333333",
            bg="white"
        ).grid(row=0, column=0, padx=8)

        self.expected_var = tk.IntVar(value=0)

        self.spin = tk.Spinbox(
            form_frame,
            from_=0,
            to=9,
            width=4,
            font=("Arial", 14, "bold"),
            textvariable=self.expected_var,
            justify="center"
        )
        self.spin.grid(row=0, column=1, padx=8)

        self.status_label = tk.Label(
            right_card,
            text="Estado: listo para dibujar.",
            font=("Arial", 11),
            fg="#333333",
            bg="white",
            wraplength=360,
            justify="center"
        )
        self.status_label.pack(pady=(8, 4))

        command_box = tk.Frame(right_card, bg="#f3f6fa", bd=0)
        command_box.pack(padx=20, pady=8, fill="x")

        tk.Label(
            command_box,
            text="Comando para ModelSim:",
            font=("Arial", 10, "bold"),
            fg="#1f3b57",
            bg="#f3f6fa"
        ).pack(pady=(8, 0))

        self.command_label = tk.Label(
            command_box,
            text="do sim/run_drawn_image.do",
            font=("Consolas", 11, "bold"),
            fg="#0b5cad",
            bg="#f3f6fa"
        )
        self.command_label.pack(pady=(2, 8))

        buttons = tk.Frame(self.root, bg="#eef2f7")
        buttons.pack(fill="x", pady=(0, 20))

        self.export_btn = tk.Button(
            buttons,
            text="Exportar archivo",
            font=("Arial", 12, "bold"),
            bg="#1f7a4d",
            fg="white",
            activebackground="#145c39",
            activeforeground="white",
            width=20,
            height=2,
            command=self.export_digit
        )
        self.export_btn.pack(side="left", padx=(190, 12))

        self.preview_btn = tk.Button(
            buttons,
            text="Previsualizar",
            font=("Arial", 12, "bold"),
            bg="#1f3b57",
            fg="white",
            activebackground="#14283d",
            activeforeground="white",
            width=18,
            height=2,
            command=self.update_preview
        )
        self.preview_btn.pack(side="left", padx=12)

        self.clear_btn = tk.Button(
            buttons,
            text="Limpiar",
            font=("Arial", 12, "bold"),
            bg="#a83232",
            fg="white",
            activebackground="#7a2525",
            activeforeground="white",
            width=16,
            height=2,
            command=self.clear_canvas
        )
        self.clear_btn.pack(side="left", padx=12)

    def start_draw(self, event):
        self.last_x = event.x
        self.last_y = event.y

    def paint(self, event):
        if self.last_x is not None and self.last_y is not None:
            brush = 24

            self.canvas.create_line(
                self.last_x,
                self.last_y,
                event.x,
                event.y,
                fill="white",
                width=brush,
                capstyle=tk.ROUND,
                smooth=True
            )

            self.draw.line(
                [self.last_x, self.last_y, event.x, event.y],
                fill=255,
                width=brush
            )

        self.last_x = event.x
        self.last_y = event.y

    def stop_draw(self, event):
        self.last_x = None
        self.last_y = None
        self.update_preview()

    def clear_canvas(self):
        self.canvas.delete("all")
        self.image = Image.new("L", (CANVAS_SIZE, CANVAS_SIZE), 0)
        self.draw = ImageDraw.Draw(self.image)
        self.status_label.config(text="Estado: lienzo limpio. Dibuja un nuevo número.")
        self.update_preview()

    def update_preview(self):
        img28 = preprocess_digit(self.image)
        zoom = img28.resize((150, 150), Image.Resampling.NEAREST)

        self.tk_preview = ImageTk.PhotoImage(zoom)
        self.preview_label.config(image=self.tk_preview)

    def export_digit(self):
        expected_digit = int(self.expected_var.get())

        img28 = preprocess_digit(self.image)
        arr28 = image28_to_int8_array(img28)

        save_hex(arr28, HEX_PATH)
        save_mif(arr28, MIF_PATH)

        img28.save(IMG28_PATH)
        self.image.save(PREVIEW_PATH)

        with open(EXPECTED_PATH, "w", encoding="utf-8") as f:
            f.write(str(expected_digit))

        write_modelsim_do(PROJECT_ROOT, expected_digit)

        self.update_preview()

        self.status_label.config(
            text="Archivo exportado correctamente. Ejecuta el comando en ModelSim."
        )

        messagebox.showinfo(
            "Exportación completada",
            "Archivo exportado correctamente.\n\n"
            "En ModelSim ejecuta:\n\n"
            "do sim/run_drawn_image.do"
        )


if __name__ == "__main__":
    root = tk.Tk()
    app = DigitExporterApp(root)
    root.mainloop()