class AssetType {
  final int id;
  final String name;
  final int? avgLifespan;
  final int? minLifespan;
  final int? maxLifespan;

  AssetType({
    required this.id,
    required this.name,
    this.avgLifespan,
    this.minLifespan,
    this.maxLifespan,
  });

  factory AssetType.fromJson(Map<String, dynamic> json) => AssetType(
    id: json['assettype_id'] as int,
    name: json['assettype_name'] as String? ?? '',
    avgLifespan: json['assettype_avg_lifespan'] as int?,
    minLifespan: json['assettype_min_lifespan'] as int?,
    maxLifespan: json['assettype_max_lifespan'] as int?,
  );
}