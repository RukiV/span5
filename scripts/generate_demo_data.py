#!/usr/bin/env python3
"""
Generate realistic demo_data.xlsx for Akademia Fasiliteitsbestuur.

- 5 jaar geskiedenis (2020-2026) vir 5-jaar tendense soos Stoele elke 5 jaar
- Werklike kampusse: Leriba, Gerhardstraat, Paarl, Moot (seed.py) met GPS
- Korrekte Aktiviteitstipes drempels 2-4 (nie 80)
- Veilige rolle: net User/Dosent/Kontrakteur via import (FK/Admin bly seed),
  onbekende Rolle default na User, Terrein net vir FK (geignoreer vir demo)
- 130 Bates met werklike name/handelsmerke en ouderdomme versprei
"""
import random
from datetime import datetime, timedelta
from pathlib import Path
import openpyxl
from openpyxl.styles import Font, Alignment, PatternFill, Border, Side

# Try to make deterministic but varied
random.seed(42)

OUTPUT = Path(__file__).parent.parent / "demo_data.xlsx"
NOW = datetime(2026, 9, 6, 8, 0, 0)  # fixed for reproducibility

HEADER_FILL = PatternFill(start_color="0E1E3B", end_color="0E1E3B", fill_type="solid")
HEADER_FONT = Font(color="FFFFFF", bold=True, size=11)
HEADER_ALIGN = Alignment(horizontal="center", vertical="center", wrap_text=True)
THIN_BORDER = Border(
    left=Side(style="thin", color="D4C4B0"),
    right=Side(style="thin", color="D4C4B0"),
    top=Side(style="thin", color="D4C4B0"),
    bottom=Side(style="thin", color="D4C4B0"),
)

def style_header(ws, row=1):
    for cell in ws[row]:
        cell.fill = HEADER_FILL
        cell.font = HEADER_FONT
        cell.alignment = HEADER_ALIGN
        cell.border = THIN_BORDER
    ws.freeze_panes = "A2"
    ws.sheet_properties.pageSetUpPr.fitToPage = True

def autosize(ws):
    for col in ws.columns:
        max_len = max(len(str(c.value or "")) for c in col)
        ws.column_dimensions[col[0].column_letter].width = min(max_len + 2, 30)

# ── Data definitions ──
TERREINE = [
    # Naam, Tipe, Straatnommer, Straatnaam, Suburb, Stad, Provinsie, Land, Lat, Long, Radius
    ["Leriba-kampus", "Kampus", "245", "Endstraat", "Clubview", "Centurion", "Gauteng", "Suid-Afrika"],
    ["Gerhardstraat-kampus", "Kampus", "117", "Gerhardstraat", "Die Hoewes", "Centurion", "Gauteng", "Suid-Afrika"],
    ["Paarl-kampus", "Kampus", "1", "Bredastraat", "Esterville", "Paarl", "Wes-Kaap", "Suid-Afrika"],
    ["Moot-sentrum", "Kampus", "1120", "Hertzogstraat", "Villieria", "Pretoria", "Gauteng", "Suid-Afrika"],
]

GEBOUE = [
    ["Boerneef", "Kantoorgebou", "Leriba-kampus"],
    ["Spys", "Kafeteria", "Leriba-kampus"],
    ["Blok L", "Onderwys", "Leriba-kampus"],
    ["Kantoor 118", "Kantoorgebou", "Gerhardstraat-kampus"],
    ["Wetenskapblok", "Laboratorium", "Gerhardstraat-kampus"],
    ["Biblioteek", "Kantoorgebou", "Paarl-kampus"],
    ["Sportkompleks", "Ander", "Paarl-kampus"],
    ["Residensie A", "Koshuis", "Moot-sentrum"],
    ["Adminblok", "Kantoorgebou", "Moot-sentrum"],
    ["Laboratorium", "Laboratorium", "Leriba-kampus"],
]

LOKALE = [
    # Naam, Kode, Tipe, Status, Kapasiteit, Gebou
    ["T1", "T1", "Klaskamer", "Operasioneel", 30, "Blok L"],
    ["T2", "T2", "Klaskamer", "Operasioneel", 25, "Blok L"],
    ["L9", "L9", "Laboratorium", "Operasioneel", 20, "Wetenskapblok"],
    ["L2", "L2", "Kantoor", "Operasioneel", 8, "Kantoor 118"],
    ["L10", "L10", "Klaskamer", "Fout Aangemeld", 35, "Blok L"],
    ["L11", "L11", "Konferensiekamer", "Operasioneel", 12, "Boerneef"],
    ["L19", "L19", "Laboratorium", "Instandhouding", 15, "Wetenskapblok"],
    ["K1", "K1", "Kantoor", "Operasioneel", 4, "Boerneef"],
    ["K2", "K2", "Kantoor", "Operasioneel", 6, "Boerneef"],
    ["K3", "K3", "Konferensiekamer", "Operasioneel", 10, "Boerneef"],
    ["RK1", "RK1", "Kantoor", "Operasioneel", 5, "Adminblok"],
    ["RK2", "RK2", "Kantoor", "Operasioneel", 5, "Adminblok"],
    ["RK3", "RK3", "Kantoor", "Operasioneel", 3, "Adminblok"],
    ["BIB01", "BIB01", "Kantoor", "Operasioneel", 20, "Biblioteek"],
    ["BIB02", "BIB02", "Klaskamer", "Operasioneel", 40, "Biblioteek"],
    ["SP01", "SP01", "Ander", "Operasioneel", 80, "Sportkompleks"],
    ["SP02", "SP02", "Pakhuis", "Operasioneel", 0, "Sportkompleks"],
    ["RES01", "RES01", "Ander", "Operasioneel", 60, "Residensie A"],
    ["RES02", "RES02", "Badkamer", "Buite Werking", 0, "Residensie A"],
    ["LAB01", "LAB01", "Laboratorium", "Operasioneel", 18, "Laboratorium"],
    ["LAB02", "LAB02", "Laboratorium", "Operasioneel", 18, "Laboratorium"],
    ["TOI01", "TOI01", "Badkamer", "Operasioneel", 0, "Boerneef"],
]

AKTIWITEITSTIPES = [
    # Naam, Gemiddelde, Min, Maks, Diensinterval, Vervangingsdrempel (korrek 2-4)
    ["Elektriese Toerusting", 60, 36, 84, 6, 3],
    ["Meubels", 120, 60, 180, 24, 2],
    ["Algemene Toerusting", 36, 12, 60, 12, 4],
    ["IT Toerusting", 48, 24, 72, 12, 3],
    ["HVAC Toerusting", 84, 60, 120, 6, 2],
    ["Veiligheidstoerusting", 36, 12, 60, 3, 4],
    ["Kombuistoerusting", 72, 36, 120, 12, 2],
]

# Realistiese bates per tipe — name, brand pools
BATE_TIPES = {
    "Elektriese Toerusting": [("Kragpunt", "Legrand"), ("Ligpunt", "Philips"), ("Skakelaar", "Schneider"), ("Kragkabel", "Aberdare")],
    "Meubels": [("Kantoor stoel", "Dauphin"), ("Tafel Barker", "Barker Street"), ("Boekrak", "Steelcase"), ("Stoel Dauphin", "Dauphin"), ("Vergadertafel", "Barker Street")],
    "IT Toerusting": [("Rekenaar HP EliteDesk", "HP"), ("Projektor Epson", "Epson"), ("Drukker Canon", "Canon"), ("Skerm Dell", "Dell"), ("Laptop Lenovo", "Lenovo")],
    "HVAC Toerusting": [("Lugversorging Samsung", "Samsung"), ("Ventilator", "KDK"), ("Verhitter", "Dimplex")],
    "Veiligheidstoerusting": [("Brandblusser SafeSys", "SafeSys"), ("Noodlig", "Eurolux"), ("Rookmelder", "System Sensor")],
    "Kombuistoerusting": [("Yskas Defy", "Defy"), ("Mikrogolfoond Samsung", "Samsung"), ("Ketel Russell", "Russell Hobbs")],
    "Algemene Toerusting": [("Handdroër Dyson", "Dyson"), ("Whiteboard", "Parrot"), ("Projektor skerm", "Barco")],
}

# Voorraad
VOORRAAD = [
    ["Skroewe M4", "Bossard", 420, 100, 1000, "Verbruiksmiddel", "Houtskroewe M4x40", "T1"],
    ["Bordmerker", "Parrot", 45, 20, 100, "Verbruiksmiddel", "Whiteboard merkers swart", "BIB01"],
    ["Gloeilamp LED", "Philips", 18, 30, 100, "Onderdele", "LED 10W E27", "LAB01"],
    ["Skoonmaakmiddel", "Dettol", 12, 15, 60, "Verbruiksmiddel", "Oppervlak ontsmetmiddel 5L", "SP01"],
    ["Filter HVAC", "Samsung", 3, 5, 20, "Onderdele", "Filter vir lugversorging", "L9"],
    ["Papier A4", "Mondi", 8, 10, 50, "Verbruiksmiddel", "A4 80gsm 500 vel", "K1"],
    ["Batterye AA", "Duracell", 60, 40, 200, "Verbruiksmiddel", "AA alkalies", "LAB02"],
    ["Seep", "Lux", 25, 30, 100, "Verbruiksmiddel", "Handseep 500ml", "TOI01"],
    ["Kabel HDMI", "Belkin", 6, 8, 30, "Onderdele", "HDMI 2m", "T2"],
    ["Brandblusser hervul", "SafeSys", 2, 3, 10, "Onderdele", "6kg poeier", "RES01"],
    ["Projektor lamp", "Epson", 1, 2, 10, "Onderdele", "ELPLP78", "L9"],
    ["Stoel wiele", "Dauphin", 14, 10, 50, "Onderdele", "Wielstel vir stoel", "K2"],
    ["Toner swart", "Canon", 4, 5, 20, "Verbruiksmiddel", "Canon 046 swart", "K1"],
    ["Handskoene", "Ansell", 30, 25, 100, "Verbruiksmiddel", "Nitril handskoene L", "SP02"],
    ["Vadoek", "Brite", 40, 30, 100, "Verbruiksmiddel", "Mikrovesel lappies", "SP01"],
]

# Gebruikers — net User/Dosent/Kontrakteur (veilig), geen FK/Admin
GEBRUIKERS = [
    ["Pieter", "Botha", "pieter@kampus.ac.za", "0821234567", "Aktief", "User"],
    ["Annelie", "Smit", "annelie@kampus.ac.za", "0821234568", "Aktief", "User"],
    ["Frikkie", "van der Merwe", "frikkie@kampus.ac.za", "0821234569", "Aktief", "Dosent"],
    ["Lize", "Pretorius", "lize@kampus.ac.za", "0821234570", "Aktief", "Dosent"],
    ["Kobus", "Botha", "kobus@bouers.co.za", "0821234571", "Aktief", "Kontrakteur"],
    ["Lindiwe", "Mokoena", "lindiwe@plumbright.co.za", "0821234572", "Aktief", "Kontrakteur"],
    ["Thabo", "Mokoena", "thabo@coolair.co.za", "0821234573", "Aktief", "Kontrakteur"],
    ["Nomsa", "Dlamini", "nomsa@kampus.ac.za", "0821234574", "Aktief", "User"],
    ["Jan", "de Beer", "jan@kampus.ac.za", "0821234575", "Aktief", "Dosent"],
    ["Sarie", "du Plessis", "sarie@kampus.ac.za", "0821234576", "Aktief", "User"],
    ["Gert", "Viljoen", "gert@kampus.ac.za", "0821234577", "Aktief", "Kontrakteur"],
    ["Elsa", "Brand", "elsa@kampus.ac.za", "0821234578", "Aktief", "User"],
]

def random_date(start: datetime, end: datetime) -> datetime:
    delta = end - start
    return start + timedelta(days=random.randint(0, delta.days), hours=random.randint(7, 17), minutes=random.choice([0, 15, 30, 45]))

def build_workbook():
    wb = openpyxl.Workbook()

    # ── Terreine ──
    ws = wb.active
    ws.title = "Terreine"
    ws.append(["Naam", "Tipe", "Straatnommer", "Straatnaam", "Suburb", "Stad", "Provinsie", "Land"])
    for row in TERREINE:
        ws.append(row)
    style_header(ws); autosize(ws)

    # ── Geboue ──
    ws = wb.create_sheet("Geboue")
    ws.append(["Naam", "Tipe", "Terrein"])
    for row in GEBOUE:
        ws.append(row)
    style_header(ws); autosize(ws)

    # ── Lokale ──
    ws = wb.create_sheet("Lokale")
    ws.append(["Naam", "Kode", "Tipe", "Status", "Kapasiteit", "Gebou"])
    for row in LOKALE:
        ws.append(row)
    style_header(ws); autosize(ws)

    # ── Aktiwiteitstipes ──
    ws = wb.create_sheet("Aktiwiteitstipes")
    ws.append(["Naam", "Gemiddelde lewensduur (maande)", "Min lewensduur (maande)", "Maks lewensduur (maande)", "Diensinterval (maande)", "Vervangingsdrempel"])
    for row in AKTIWITEITSTIPES:
        ws.append(row)
    style_header(ws); autosize(ws)

    # ── Bates 130 met 5-jaar verspreiding ──
    ws = wb.create_sheet("Bates")
    ws.append(["Naam", "Merk", "Serienommer", "Status", "Buite", "Geskep", "Tipe", "Lokaal"])
    statuses = ["Aktief", "Aktief", "Aktief", "Aktief", "Instandhouding", "Afgedank", "Onaktief"]
    # Also include some Instandhouding/ Afgedank for realism
    bates_list = []
    asset_counter = 1
    for atype, brand_pools in BATE_TIPES.items():
        # Distribute ~130 across types proportionally
        count = {"Elektriese Toerusting": 18, "Meubels": 30, "IT Toerusting": 28, "HVAC Toerusting": 14, "Veiligheidstoerusting": 12, "Kombuistoerusting": 14, "Algemene Toerusting": 14}[atype]
        for i in range(count):
            name, brand = random.choice(brand_pools)
            # Serial per type with prefix
            prefix = {"Elektriese Toerusting": "EL", "Meubels": "MB", "IT Toerusting": "IT", "HVAC Toerusting": "HV", "Veiligheidstoerusting": "VS", "Kombuistoerusting": "KB", "Algemene Toerusting": "AG"}[atype]
            serial = f"{prefix}-{asset_counter:05d}"
            status = random.choice(statuses)
            # Buite only ~5% for HVAC outdoor
            is_outdoor = "Ja" if atype == "HVAC Toerusting" and random.random() < 0.35 else "Nee"
            # Created 2020-2026 spread for 5-year trends, bias older for Meubels to show 5-year break
            if atype == "Meubels" and i < 10:
                # Force older chairs to demonstrate 5-year break
                age_days = random.randint(1500, 1825)  # 4-5 years
            else:
                age_days = random.randint(30, 1825)  # 1 month to 5 years
            created = NOW - timedelta(days=age_days)
            created_str = created.strftime("%Y-%m-%d %H:%M:%S")
            # Lokaal round-robin but realistic room per type
            lokaal = random.choice([r[0] for r in LOKALE])
            ws.append([f"{name} {asset_counter}", brand, serial, status, is_outdoor, created_str, atype, lokaal])
            bates_list.append((f"{name} {asset_counter}", serial, atype, lokaal, created))
            asset_counter += 1
    style_header(ws); autosize(ws)
    ws.column_dimensions["F"].width = 19
    ws.column_dimensions["G"].width = 22
    for row in ws.iter_rows(min_row=2, max_row=ws.max_row, min_col=6, max_col=6):
        for cell in row:
            cell.number_format = "YYYY-MM-DD HH:MM:SS"

    # ── Voorraad ──
    ws = wb.create_sheet("Voorraad")
    ws.append(["Naam", "Merk", "Hoeveelheid", "Minimum", "Boks Totaal", "Tipe", "Beskrywing", "Lokaal"])
    for row in VOORRAAD:
        ws.append(row)
    style_header(ws); autosize(ws)

    # ── Gebruikers — net 3 rolle, geen Terrein ──
    ws = wb.create_sheet("Gebruikers")
    ws.append(["Voornaam", "Van", "E-pos", "Selnommer", "Status", "Rol"])
    for row in GEBRUIKERS:
        ws.append(row)
    style_header(ws); autosize(ws)
    ws.column_dimensions["C"].width = 26
    ws.column_dimensions["F"].width = 14

    # ── Foutkaartjies 40 met 5-jaar verspreiding ──
    ws = wb.create_sheet("Foutkaartjies")
    ws.append(["Titel", "Kategorie", "Status", "Prioriteit", "Datum", "Lokaal", "Bate", "Gebou", "Terrein", "Aangeer (e-pos)"])
    fault_titles = [
        ("Stoel se wiel gebreek", "Herstel", "Meubels"),
        ("Tafel poot los", "Herstel", "Meubels"),
        ("Lig flikker", "Herstel", "Elektriese Toerusting"),
        ("Rekenaar start nie", "Herstel", "IT Toerusting"),
        ("Lugversorging koel nie", "Herstel", "HVAC Toerusting"),
        ("Brandblusser verval", "Onderhoud", "Veiligheidstoerusting"),
        ("Yskas lek water", "Herstel", "Kombuistoerusting"),
        ("Projektor beeld dof", "Herstel", "IT Toerusting"),
        ("Kragpunt werk nie", "Herstel", "Elektriese Toerusting"),
        ("Whiteboard merk bly", "Onderhoud", "Algemene Toerusting"),
    ]
    statuses_f = ["Oop", "Wag", "Bevestig", "Besig", "Opgelos", "Gesluit"]
    priorities = ["Laag", "Medium", "Hoog"]
    categories = ["Herstel", "Onderhoud", "Inspeksie", "Installasie"]
    # Spread 40 faults over 5 years, more recent concentrated for 12m window
    for i in range(40):
        title, cat, _ = random.choice(fault_titles)
        # Bias: 20 within last 12 months, 20 older 1-5 years
        if i < 20:
            days_ago = random.randint(0, 365)
        else:
            days_ago = random.randint(366, 1825)
        # Add some faults every year to show 5-year trend, especially for Meubels every ~5 years
        if i % 8 == 0:
            days_ago = random.randint(1500, 1825)  # 4-5 years ago for trend
            title = "Stoel se wiel gebreek"
            cat = "Herstel"
        fault_date = NOW - timedelta(days=days_ago, hours=random.randint(7, 17))
        status = random.choice(statuses_f)
        # Hoog priority more for recent
        prio = "Hoog" if days_ago < 90 and random.random() < 0.4 else random.choice(priorities)
        lokaal = random.choice([r[0] for r in LOKALE])
        # Bate: link to actual Bates serials for referential integrity
        # Pick from bates_list that matches the fault's asset class
        meubels_serials = [s for _, s, at, _, _ in bates_list if at == "Meubels"]
        it_serials = [s for _, s, at, _, _ in bates_list if at == "IT Toerusting"]
        hvac_serials = [s for _, s, at, _, _ in bates_list if at == "HVAC Toerusting"]
        if "Stoel" in title and meubels_serials:
            bate = random.choice(meubels_serials)
            # Use the bates actual lokaal for consistency 30% of time
            if random.random() < 0.3:
                for _, s, _, loc, _ in bates_list:
                    if s == bate:
                        lokaal = loc
                        break
        elif "Tafel" in title and meubels_serials:
            bate = random.choice(meubels_serials)
            if random.random() < 0.3:
                for _, s, _, loc, _ in bates_list:
                    if s == bate:
                        lokaal = loc
                        break
        elif "Rekenaar" in title or "Projektor" in title:
            bate = random.choice(it_serials) if it_serials else ""
        elif "Lugversorging" in title and hvac_serials:
            bate = random.choice(hvac_serials)
        else:
            bate = random.choice([s for _, s, _, _, _ in bates_list]) if random.random() < 0.4 else ""  # 40% linked
        gebou = random.choice([g[0] for g in GEBOUE]) if random.random() < 0.3 else ""
        terrein = ""  # usually via gebou
        aangeer = random.choice([u[2] for u in GEBRUIKERS[:4]])
        ws.append([title, random.choice(categories) if random.random()<0.2 else cat, status, prio, fault_date.strftime("%Y-%m-%d %H:%M:%S"), lokaal, bate, gebou, terrein, aangeer])
    style_header(ws); autosize(ws)
    ws.column_dimensions["E"].width = 19

    # ── Kotasies 15 ──
    ws = wb.create_sheet("Kotasies")
    ws.append(["Datum", "Status", "Keuse rede", "Kontrakteur (e-pos)"])
    quote_statuses = ["Nuut", "Aanvaar", "Verwerp"]
    for i in range(15):
        qdate = NOW - timedelta(days=random.randint(0, 180))
        status = random.choice(quote_statuses)
        rede = random.choice(["Goedkoopste aanbod", "Vinnigste diens", "Beste gehalte", "Voorkeur verskaffer"])
        kontrakteur = random.choice([u[2] for u in GEBRUIKERS if u[5]=="Kontrakteur"])
        ws.append([qdate.strftime("%Y-%m-%d"), status, rede, kontrakteur])
    style_header(ws); autosize(ws)

    # ── Werksopdragte 40 ──
    ws = wb.create_sheet("Werksopdragte")
    ws.append(["Beskrywing", "Status", "Werksoort", "Prioriteit", "Aard", "Notas", "Geskep", "Geskeduleerde datum", "Einddatum", "Voltooidatum", "Lokaal", "Bate", "Gebou", "Terrein", "Toegewys", "Kontrakteur (e-pos)", "Foutkaartjie", "Kwotasies"])
    job_statuses = ["Wag", "Oop", "Geskeduleer", "Besig", "Voltooid", "Gekanselleer"]
    job_types = ["Onderhoud", "Herstel", "Inspeksie", "Installasie"]
    priorities_j = ["Laag", "Medium", "Hoog"]
    for i in range(40):
        desc = random.choice(["Vervang projektorlamp", "Herstel kragpunt L9", "Diens lugversorging", "Vervang stoel wiele", "Skoonmaak filter HVAC", "Her-stel tafel poot", "Ondersoek kragonderbreking", "Installeer whiteboard"])
        status = random.choice(job_statuses)
        jtype = random.choice(job_types)
        prio = random.choice(priorities_j)
        aard = random.choice(["Instandhouding", "Voorkomend", "Korrektief"])
        notas = ""
        geskep = NOW - timedelta(days=random.randint(0, 365), hours=random.randint(0, 12))
        gesked = geskep + timedelta(days=random.randint(1, 14))
        eind = gesked + timedelta(days=random.randint(1, 5))
        voltooi = eind + timedelta(days=random.randint(0, 3)) if status == "Voltooid" else ""
        lokaal = random.choice([r[0] for r in LOKALE])
        # Use actual Bates serials for referential integrity
        if random.random() < 0.5 and bates_list:
            bate = random.choice([s for _, s, _, _, _ in bates_list])
            # Occasionally align lokaal with bate's actual lokaal
            if random.random() < 0.3:
                for _, s, _, loc, _ in bates_list:
                    if s == bate:
                        lokaal = loc
                        break
        else:
            bate = ""
        gebou = random.choice([g[0] for g in GEBOUE]) if random.random()<0.3 else ""
        terrein = ""
        toegewys = random.choice([u[2] for u in GEBRUIKERS if u[5] in ("User","Dosent")]) if random.random()<0.7 else ""
        kontrakteur = random.choice([u[2] for u in GEBRUIKERS if u[5]=="Kontrakteur"]) if random.random()<0.5 else ""
        # Format dates
        def fmt(d): return d.strftime("%Y-%m-%d %H:%M:%S") if isinstance(d, datetime) else ""
        ws.append([desc, status, jtype, prio, aard, notas, fmt(geskep), fmt(gesked), fmt(eind), fmt(voltooi) if voltooi else "", lokaal, bate, gebou, terrein, toegewys, kontrakteur, "", ""])
    style_header(ws); autosize(ws)
    for col in ["G","H","I","J"]:
        ws.column_dimensions[col].width = 19

    # Print settings
    for ws in wb.worksheets:
        ws.sheet_properties.pageSetUpPr.fitToPage = True
        ws.page_setup.fitToWidth = 1
        ws.page_setup.fitToHeight = 0
        ws.page_setup.orientation = "landscape"

    wb.save(OUTPUT)
    print(f"Generated {OUTPUT} with {len(wb.sheetnames)} sheets: {', '.join(wb.sheetnames)}")
    # Also print stats
    for ws in wb.worksheets:
        print(f"  {ws.title}: {ws.max_row-1} rows")

if __name__ == "__main__":
    build_workbook()
