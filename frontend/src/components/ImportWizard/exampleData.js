// Voorbeeld-rye per tabel — presies die kanonieke koppe wat die invoer/outo-mapping
// en die uitvoer gebruik. Waardes is geldige voorbeelde (enums, Ja/Nee, datumformate,
// verwysings volgens naam / kode / e-pos).

export const EXAMPLE_ROWS = {
  location: {
    columns: ['Naam', 'Tipe', 'Straatnommer', 'Straatnaam', 'Suburb', 'Stad', 'Provinsie', 'Land'],
    rows: [
      ['Hoofkampus', 'Kampus', '1', 'Kerkstraat', 'Matieland', 'Stellenbosch', 'Wes-Kaap', 'Suid-Afrika'],
      ['Tuinesentrum', 'Sub-kampus', '22', 'Dorpsstraat', '', 'Kaapstad', 'Wes-Kaap', ''],
    ],
    refs: [false, false, false, false, false, false, false, false],
  },
  building: {
    columns: ['Naam', 'Tipe', 'Terrein'],
    rows: [
      ['A Blok', 'Onderwys', 'Hoofkampus'],
      ['Biblioteek', 'Kantoorgebou', 'Hoofkampus'],
    ],
    refs: [false, false, true],
  },
  room: {
    columns: ['Naam', 'Kode', 'Tipe', 'Status', 'Gebou', 'Kapasiteit'],
    rows: [
      ['A101', 'A101', 'Klaskamer', 'Operasioneel', 'A Blok', '30'],
      ['Rekenaarlab 2', 'LAB002', 'Laboratorium', 'Operasioneel', 'A Blok', '25'],
    ],
    refs: [false, false, false, false, true, false],
  },
  assettype: {
    columns: [
      'Naam',
      'Gemiddelde lewensduur (maande)',
      'Min lewensduur (maande)',
      'Maks lewensduur (maande)',
      'Diensinterval (maande)',
      'Vervangingsdrempel',
    ],
    rows: [
      ['IT Toerusting', '48', '24', '72', '12', '3'],
      ['Meubels', '120', '60', '180', '24', '2'],
    ],
    refs: [false, false, false, false, false, false],
  },
  asset: {
    columns: ['Naam', 'Merk', 'Serienommer', 'Status', 'Buite', 'Geskep', 'Tipe', 'Lokaal'],
    rows: [
      ['HP EliteDesk', 'HP', 'SN001', 'Aktief', 'Nee', '2024-01-15 08:00:00', 'Rekenaar', 'A101'],
      ['Epson Projektor', 'Epson', 'SN002', 'Aktief', 'Nee', '2023-11-02 10:15:00', 'Projektor', 'Rekenaarlab 2'],
    ],
    refs: [false, false, false, false, false, false, true, true],
  },
  stock: {
    columns: ['Naam', 'Merk', 'Hoeveelheid', 'Minimum', 'Boks Totaal', 'Tipe', 'Beskrywing', 'Lokaal'],
    rows: [
      ['Stofsuier', 'Bosch', '4', '1', '2', 'Toerusting', 'Industri\u00eble stofsuier', 'Rekenaarlab 2'],
      ['Skroewe M4', 'Bossard', '500', '100', '1000', 'Verbruiksmiddel', '', ''],
    ],
    refs: [false, false, false, false, false, false, false, true],
  },
  user: {
    columns: ['Voornaam', 'Van', 'E-pos', 'Selnommer', 'Status', 'Rol'],
    rows: [
      ['Pieter', 'Botha', 'pieter@kampus.ac.za', '0821234567', 'Aktief', 'User'],
      ['Lize', 'Pretorius', 'lize@kampus.ac.za', '0821234570', 'Aktief', 'Dosent'],
      ['Kobus', 'Botha', 'kobus@bouers.co.za', '0821234571', 'Aktief', 'Kontrakteur'],
    ],
    refs: [false, false, false, false, false, false],
  },
  fault: {
    columns: [
      'Titel', 'Kategorie', 'Status', 'Prioriteit', 'Datum',
      'Lokaal', 'Bate', 'Gebou', 'Terrein', 'Aangeer (e-pos)',
    ],
    rows: [
      ['Projector skakel nie aan nie', 'Herstel', 'Oop', 'Hoog', '2025-06-01 07:45:00',
        'A101', 'SN002', '', '', 'pieter@kampus.ac.za'],
      ['Lek in plafon', 'Onderhoud', 'Besig', 'Medium', '2025-06-03 14:20:00',
        '', '', 'A Blok', 'Hoofkampus', 'susan@kampus.ac.za'],
    ],
    refs: [false, false, false, false, false, true, true, true, true, true],
  },
  quote: {
    columns: ['Datum', 'Status', 'Keuse rede', 'Kontrakteur (e-pos)'],
    rows: [
      ['2025-06-10', 'Nuut', 'Goedkoopste aanbod', 'daan@kampus.co.za'],
    ],
    refs: [false, false, false, true],
  },
  job: {
    columns: [
      'Beskrywing', 'Status', 'Werksoort', 'Prioriteit', 'Aard', 'Notas',
      'Geskep', 'Geskeduleerde datum', 'Einddatum', 'Voltooidatum',
      'Lokaal', 'Bate', 'Gebou', 'Terrein', 'Toegewys',
      'Kontrakteur (e-pos)', 'Foutkaartjie', 'Kwotasies',
    ],
    rows: [
      ['Vervang projektorlamp', 'Geskeduleer', 'Herstel', 'Hoog', 'Instandhouding', 'Lamp deelnr. ELPLP78',
        '2025-06-04 09:00:00', '2025-06-05 08:00:00', '2025-06-05 12:00:00', '',
        'A101', 'SN002', '', '', 'pieter@kampus.ac.za', '', 'Projector skakel nie aan nie',
        '2025-06-01;daan@kampus.co.za|2025-06-02;karla@kampus.co.za'],
    ],
    refs: [false, false, false, false, false, false, false, false, false, false,
      true, true, true, true, true, true, true, false],
  },
};

export const EXAMPLE_NOTES = [
  'Booleans as Ja / Nee.',
  'Datums as Jaar-Maand-Dag (bv. 2025-06-01 of 2025-06-01 08:00:00).',
  'Verwysings (⟶) word volgens naam / kode / e-pos opgesoek soos hierbo getoon.',
  'Kwotasies op \'n werksopdrag: "datum;kontrakteur-e-pos" per kwotasie, geskei met |.',
  'Een werkboek mag verskeie bladsye hê — elke blad kan na \'n ander tabel wys.',
  'Rol: slegs User / Dosent / Kontrakteur via import (FK/Admin bly seed); onbekend → User, net FK het Terrein (via seed).',
  'Vervangingsdrempel: 1-10 (nie 80 nie), en Min ≤ Gemiddeld ≤ Maks.',
];
