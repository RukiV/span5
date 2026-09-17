/// Vertaal backend-voorstellingsleutels (EN) na die Afrikaanse waarde wat die
/// vorm-aflelys gebruik. Die reëls-klassifiseerder lewer tipe/prioriteit as
/// hoofletter-EN-kodes terug (bv. 'REPAIR', 'MEDIUM'); `nature`, `asset_brand`
/// en `stock_brand` kom reeds Afrikaans terug en word nie hier geraak nie.
library;

const Map<String, String> _jobTypeEnAf = {
  'REPAIR': 'Herstel',
  'MAINTENANCE': 'Onderhoud',
  'INSPECTION': 'Inspeksie',
  'INSTALLATION': 'Installasie',
};

const Map<String, String> _faultTypeEnAf = _jobTypeEnAf;

const Map<String, String> _jobPriorityEnAf = {
  'LOW': 'Laag',
  'MEDIUM': 'Normal',
  'HIGH': 'Hoog',
};

const Map<String, String> _faultPriorityEnAf = {
  'LOW': 'Laag',
  'MEDIUM': 'Medium',
  'HIGH': 'Hoog',
};

/// Vertaal 'n voorstel vir [key] na die Afrikaanse vertoonwaarde, of gee die
/// waarde onveranderd terug as geen vertaling bestaan nie.
String translateSuggestion(String key, String value) {
  final upper = value.toUpperCase();
  switch (key) {
    case 'job_type':
      return _jobTypeEnAf[upper] ?? value;
    case 'job_priority':
      return _jobPriorityEnAf[upper] ?? value;
    case 'fault_type':
    case 'suggested_type':
    case 'asset_type':
      return _faultTypeEnAf[upper] ?? value;
    case 'fault_priority':
    case 'suggested_priority':
      return _faultPriorityEnAf[upper] ?? value;
    default:
      return value;
  }
}