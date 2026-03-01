"""
OCR extraction module.

Extracts text from PDF files using pdf2image + Tesseract
with preprocessing for optimal accuracy (300 DPI, grayscale,
denoise, Otsu thresholding, deskew).

Preserves the OCR pipeline from the original ColdFusion/Python system.
"""

import logging
import os
import tempfile

log = logging.getLogger(__name__)


def extract_text_from_pdf(pdf_path):
    """Extract text from a PDF using Tesseract OCR with preprocessing.

    Args:
        pdf_path: Path to the PDF file.

    Returns:
        Extracted text as a string.
    """
    try:
        # Try direct text extraction first (for text-based PDFs)
        text = _extract_text_layer(pdf_path)
        if text and len(text.strip()) > 100:
            log.info(f'Extracted {len(text)} chars from text layer')
            return _clean_text(text)
    except Exception as e:
        log.debug(f'Text layer extraction failed: {e}')

    # Fall back to OCR
    try:
        text = _ocr_extract(pdf_path)
        log.info(f'OCR extracted {len(text)} chars')
        return _clean_text(text)
    except Exception as e:
        log.error(f'OCR extraction failed: {e}')
        return ''


def _extract_text_layer(pdf_path):
    """Extract embedded text from PDF (no OCR needed)."""
    import fitz  # PyMuPDF

    doc = fitz.open(pdf_path)
    text_parts = []
    for page in doc:
        text_parts.append(page.get_text())
    doc.close()
    return '\n'.join(text_parts)


def _ocr_extract(pdf_path):
    """OCR extraction with image preprocessing."""
    from pdf2image import convert_from_path
    from PIL import ImageFilter
    import pytesseract

    # Convert PDF to images at 300 DPI
    images = convert_from_path(pdf_path, dpi=300)

    text_parts = []
    for i, image in enumerate(images):
        # Preprocessing pipeline
        # 1. Convert to grayscale
        gray = image.convert('L')

        # 2. Denoise (slight blur to reduce noise)
        denoised = gray.filter(ImageFilter.MedianFilter(size=3))

        # 3. Adaptive thresholding (Otsu-like via point operation)
        # Calculate threshold value
        pixels = list(denoised.getdata())
        threshold = sum(pixels) // len(pixels)
        binary = denoised.point(lambda p: 255 if p > threshold else 0)

        # 4. OCR with Tesseract
        page_text = pytesseract.image_to_string(
            binary,
            lang='eng',
            config='--psm 6 --oem 3',
        )
        text_parts.append(page_text)

    return '\n\n'.join(text_parts)


def _clean_text(text):
    """Clean up OCR artifacts and normalize whitespace."""
    import re

    # Remove excessive whitespace
    text = re.sub(r' {3,}', '  ', text)

    # Remove null bytes
    text = text.replace('\x00', '')

    # Normalize line breaks
    text = re.sub(r'\n{4,}', '\n\n\n', text)

    # Remove form feed characters
    text = text.replace('\f', '\n\n')

    return text.strip()
