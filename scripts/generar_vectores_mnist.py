from pathlib import Path
import argparse
import csv

import numpy as np
from PIL import Image
from tensorflow.keras.datasets import mnist


def guardar_hex_imagen(img_28x28: np.ndarray, ruta_hex: Path):
    """
    Guarda una imagen 28x28 en un archivo .hex de 784 líneas.
    Cada línea tiene un pixel en hexadecimal de 8 bits.
    El rango usado es 0 a 127 para trabajar como signed int8 positivo.
    """
    img = img_28x28.astype(np.float32)

    # MNIST viene entre 0 y 255. Se escala a 0..127.
    img_int8 = np.round((img / 255.0) * 127.0).astype(np.int16)

    with open(ruta_hex, "w", encoding="utf-8") as f:
        for value in img_int8.flatten():
            value = int(np.clip(value, 0, 127))
            f.write(f"{value & 0xFF:02X}\n")


def guardar_preview(img_28x28: np.ndarray, ruta_png: Path):
    """
    Guarda una imagen de vista previa para anexarla al informe o presentación.
    """
    Image.fromarray(img_28x28.astype(np.uint8)).resize((280, 280)).save(ruta_png)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--out_dir",
        type=str,
        default="sim/data",
        help="Carpeta donde se guardarán las imágenes .hex"
    )
    parser.add_argument(
        "--indices",
        type=int,
        nargs="+",
        default=[0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
        help="Índices de imágenes MNIST de prueba"
    )
    args = parser.parse_args()

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    (_, _), (x_test, y_test) = mnist.load_data()

    labels_path = out_dir / "labels.csv"

    with open(labels_path, "w", newline="", encoding="utf-8") as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(["test_id", "mnist_index", "label", "hex_file", "preview_png"])

        for test_id, idx in enumerate(args.indices):
            img = x_test[idx]
            label = int(y_test[idx])

            hex_name = f"img_{test_id:03d}_label_{label}.hex"
            png_name = f"img_{test_id:03d}_label_{label}.png"

            guardar_hex_imagen(img, out_dir / hex_name)
            guardar_preview(img, out_dir / png_name)

            writer.writerow([test_id, idx, label, hex_name, png_name])

            print(f"[OK] {hex_name} | MNIST index={idx} | label={label}")

    print(f"\nArchivo de etiquetas generado en: {labels_path}")


if __name__ == "__main__":
    main()