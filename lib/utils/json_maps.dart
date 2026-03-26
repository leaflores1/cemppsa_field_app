Map<String, dynamic> convertToStringDynamicMap(Map raw) {
  return raw.map((key, value) {
    if (value is Map) {
      return MapEntry(key.toString(), convertToStringDynamicMap(value));
    }
    if (value is List) {
      return MapEntry(key.toString(), _convertDynamicList(value));
    }
    return MapEntry(key.toString(), value);
  });
}

List<dynamic> _convertDynamicList(List<dynamic> list) {
  return list.map((item) {
    if (item is Map) {
      return convertToStringDynamicMap(item);
    }
    if (item is List) {
      return _convertDynamicList(item);
    }
    return item;
  }).toList();
}
