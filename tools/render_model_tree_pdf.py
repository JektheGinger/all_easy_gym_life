from pathlib import Path
import re

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    KeepTogether,
    PageTemplate,
    Paragraph,
    Preformatted,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "MODEL_TREE.md"
OUTPUT = ROOT / "output" / "pdf" / "EASY_GYM_LIFE_REPOSITORY_MODEL_TREE.pdf"


class NumberedCanvasMixin:
    pass


def footer(canvas, doc):
    canvas.saveState()
    width, _ = letter
    canvas.setStrokeColor(colors.HexColor("#DCE8E1"))
    canvas.setLineWidth(0.5)
    canvas.line(0.65 * inch, 0.52 * inch, width - 0.65 * inch, 0.52 * inch)
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(colors.HexColor("#5D746A"))
    canvas.drawString(0.65 * inch, 0.33 * inch, "Easy Gym Life - Repository Model Tree")
    canvas.drawRightString(
        width - 0.65 * inch, 0.33 * inch, f"Page {canvas.getPageNumber()}"
    )
    canvas.restoreState()


def inline_markup(text):
    text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    text = re.sub(r"`([^`]+)`", r'<font name="Courier">\1</font>', text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", text)
    return text


def parse_table(lines, index, styles):
    rows = []
    while index < len(lines) and lines[index].strip().startswith("|"):
        cells = [cell.strip() for cell in lines[index].strip().strip("|").split("|")]
        rows.append(cells)
        index += 1

    if len(rows) >= 2 and all(set(cell) <= set("-: ") for cell in rows[1]):
        rows.pop(1)

    data = []
    for row_index, row in enumerate(rows):
        style = styles["table_header"] if row_index == 0 else styles["table_cell"]
        data.append([Paragraph(inline_markup(cell), style) for cell in row])

    available = 7.15 * inch
    columns = max(len(row) for row in data)
    widths = [available / columns] * columns
    table = Table(data, colWidths=widths, repeatRows=1, hAlign="LEFT")
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#153E32")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#BFD2C8")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 6),
                ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F3F8F5")]),
            ]
        )
    )
    return table, index


def build_story(markdown):
    base = getSampleStyleSheet()
    styles = {
        "title": ParagraphStyle(
            "Title",
            parent=base["Title"],
            fontName="Helvetica-Bold",
            fontSize=24,
            leading=29,
            textColor=colors.HexColor("#123A2F"),
            alignment=TA_CENTER,
            spaceAfter=15,
        ),
        "subtitle": ParagraphStyle(
            "Subtitle",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=10,
            leading=15,
            textColor=colors.HexColor("#5D746A"),
            alignment=TA_CENTER,
            spaceAfter=20,
        ),
        "h1": ParagraphStyle(
            "H1",
            parent=base["Heading1"],
            fontName="Helvetica-Bold",
            fontSize=17,
            leading=21,
            textColor=colors.HexColor("#123A2F"),
            spaceBefore=12,
            spaceAfter=8,
            keepWithNext=True,
        ),
        "h2": ParagraphStyle(
            "H2",
            parent=base["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=13,
            leading=17,
            textColor=colors.HexColor("#2A6754"),
            spaceBefore=9,
            spaceAfter=6,
            keepWithNext=True,
        ),
        "body": ParagraphStyle(
            "Body",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=9.4,
            leading=13.4,
            textColor=colors.HexColor("#23372F"),
            spaceAfter=6,
        ),
        "bullet": ParagraphStyle(
            "Bullet",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=9.2,
            leading=13,
            leftIndent=15,
            firstLineIndent=-8,
            textColor=colors.HexColor("#23372F"),
            spaceAfter=3,
        ),
        "code": ParagraphStyle(
            "Code",
            parent=base["Code"],
            fontName="Courier",
            fontSize=6.7,
            leading=8.5,
            leftIndent=8,
            rightIndent=8,
            borderColor=colors.HexColor("#C5D8CE"),
            borderWidth=0.6,
            borderPadding=8,
            backColor=colors.HexColor("#F2F7F4"),
            textColor=colors.HexColor("#173B30"),
            spaceBefore=4,
            spaceAfter=8,
        ),
        "table_header": ParagraphStyle(
            "TableHeader",
            parent=base["BodyText"],
            fontName="Helvetica-Bold",
            fontSize=7.5,
            leading=9.5,
            textColor=colors.white,
        ),
        "table_cell": ParagraphStyle(
            "TableCell",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=7.3,
            leading=9.3,
            textColor=colors.HexColor("#23372F"),
        ),
    }

    lines = markdown.splitlines()
    story = []
    paragraph_parts = []
    code_lines = []
    in_code = False
    title_seen = False

    def flush_paragraph():
        if paragraph_parts:
            text = " ".join(part.strip() for part in paragraph_parts)
            story.append(Paragraph(inline_markup(text), styles["body"]))
            paragraph_parts.clear()

    index = 0
    while index < len(lines):
        raw = lines[index]
        stripped = raw.strip()

        if stripped.startswith("```"):
            flush_paragraph()
            if in_code:
                story.append(Preformatted("\n".join(code_lines), styles["code"], maxLineLength=108))
                code_lines = []
                in_code = False
            else:
                in_code = True
            index += 1
            continue

        if in_code:
            code_lines.append(raw)
            index += 1
            continue

        if stripped.startswith("|"):
            flush_paragraph()
            table, index = parse_table(lines, index, styles)
            story.append(table)
            story.append(Spacer(1, 7))
            continue

        if not stripped:
            flush_paragraph()
            index += 1
            continue

        if stripped.startswith("# "):
            flush_paragraph()
            if not title_seen:
                story.append(Spacer(1, 0.3 * inch))
                story.append(Paragraph(inline_markup(stripped[2:]), styles["title"]))
                story.append(
                    Paragraph(
                        "Architecture, file dependencies, runtime flow, platform adapters, "
                        "and tracked-file inventory",
                        styles["subtitle"],
                    )
                )
                title_seen = True
            else:
                story.append(Paragraph(inline_markup(stripped[2:]), styles["h1"]))
            index += 1
            continue

        if stripped.startswith("## "):
            flush_paragraph()
            story.append(Paragraph(inline_markup(stripped[3:]), styles["h1"]))
            index += 1
            continue

        if stripped.startswith("### "):
            flush_paragraph()
            story.append(Paragraph(inline_markup(stripped[4:]), styles["h2"]))
            index += 1
            continue

        if re.match(r"^[-*] ", stripped):
            flush_paragraph()
            story.append(
                Paragraph("• " + inline_markup(stripped[2:]), styles["bullet"])
            )
            index += 1
            continue

        numbered = re.match(r"^(\d+)\.\s+(.*)", stripped)
        if numbered:
            flush_paragraph()
            story.append(
                Paragraph(
                    f"{numbered.group(1)}. {inline_markup(numbered.group(2))}",
                    styles["bullet"],
                )
            )
            index += 1
            continue

        paragraph_parts.append(stripped)
        index += 1

    flush_paragraph()
    return story


def main():
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    markdown = SOURCE.read_text(encoding="utf-8")
    story = build_story(markdown)

    doc = BaseDocTemplate(
        str(OUTPUT),
        pagesize=letter,
        leftMargin=0.65 * inch,
        rightMargin=0.65 * inch,
        topMargin=0.62 * inch,
        bottomMargin=0.68 * inch,
        title="Easy Gym Life Repository Model Tree",
        author="Codex",
        subject="Flutter, backend, database, asset, platform, and documentation relationships",
    )
    frame = Frame(doc.leftMargin, doc.bottomMargin, doc.width, doc.height, id="body")
    doc.addPageTemplates([PageTemplate(id="main", frames=[frame], onPage=footer)])
    doc.build(story)
    print(OUTPUT)


if __name__ == "__main__":
    main()
