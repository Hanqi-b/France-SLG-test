# France SLG Map Data Rules

This document records the provenance, transformation rules, and game-value formulas for the France SLG map dataset.

## Files

- `fr_downloaded.svg`: source SVG map for French second-level administrative areas.
- `provinces.json`: per-department map geometry, centers, adjacency, Eurostat statistics, and game values.
- `regions_pre_2016.json`: former 22 metropolitan regions before the 2016 regional reform.
- `regions_post_2016.json`: 13 metropolitan regions after the 2016 regional reform.

## Map Source

The base map is the SimpleMaps France SVG admin level 2 map:

https://simplemaps.com/svg/country/fr#admin2

The SimpleMaps page states that the admin level 2 France SVG is simplified for web use, identifies second-level administrative regions by `name` and `id` in the SVG source, and uses a Mercator projection.

License page:

https://simplemaps.com/resources/svg-license

The SimpleMaps license page says the SVG maps are free for personal or commercial use, with attribution appreciated. It also says the maps should not be redistributed as an unchanged map collection without permission, and the library is provided as-is without reliability guarantees.

## Statistical Sources

Population and GDP were added from Eurostat NUTS 3 datasets for year 2022.

Population:

https://ec.europa.eu/eurostat/databrowser/view/demo_r_pjanaggr3/default/table

- Dataset: `demo_r_pjanaggr3`
- Measure: Population on 1 January by broad age group, sex and NUTS 3 region
- Filters used: `sex=T`, `age=TOTAL`, `unit=NR`, `time=2022`
- Stored under: `stats.2022.population.value`

GDP:

https://ec.europa.eu/eurostat/databrowser/view/nama_10r_3gdp/default/table

- Dataset: `nama_10r_3gdp`
- Measure: Gross domestic product at current market prices by NUTS 3 region
- Filters used: `unit=MIO_EUR`, `time=2022`
- Stored under: `stats.2022.economy.gdp_current_market_prices.value`

GDP per capita is derived locally:

```text
gdp_per_capita = gdp_million_eur * 1,000,000 / population
```

## Department Matching

The SVG uses department-style IDs such as `FR59`, `FR75`, `FR2A`, and `FR2B`. Eurostat uses NUTS 3 region codes. The enrichment script matches SVG departments to Eurostat NUTS 3 units by normalized department name.

Name normalization:

- Convert to lowercase.
- Remove accents/diacritics.
- Normalize punctuation and whitespace.
- Compare normalized strings.

Manual corrections currently used:

- `Haute-Rhin` from the SVG is matched to Eurostat `Haut-Rhin`.
- `Seien-et-Marne` from the SVG is matched to Eurostat `Seine-et-Marne`.

## Centers

The SVG includes a `label_points` group. Its circles are used as UI/map centers:

- Army travel start/end points.
- Province labels.
- Province status UI anchors.

These are display label points, not guaranteed administrative capitals or geometric centroids.

## Neighbor Algorithm

Neighbors in `provinces.json` are generated from SVG boundaries, not typed by hand.

Algorithm name: `sampled_boundary_contact`

Steps:

1. Parse each province SVG path.
2. Sample each boundary at about `2 px` intervals.
3. Insert sampled points into a spatial grid.
4. For two provinces, count boundary point pairs within `1.35 px`.
5. Accept the pair as neighbors only if:
   - shared sample count is at least `6`
   - shared contact span is at least `5 px`

This avoids most false positives caused by single-point corner touches. Coastal, island, and very short-border cases should still be manually reviewed before final game balancing.

## Game Value Rules

The game uses compressed values instead of raw GDP/population because raw values have very large ranges.

For 2022 data:

- GDP minimum: `2233.9` million EUR
- GDP maximum: `261799.0` million EUR
- Population minimum: `76503`
- Population maximum: `2616909`

Both game values are scaled to the integer range `10..100`.

### Tax Base

`tax_base` is derived from GDP at current market prices:

```text
tax_base = round(10 + 90 * ln(gdp / min_gdp) / ln(max_gdp / min_gdp))
```

Input:

```text
stats.2022.economy.gdp_current_market_prices.value
```

Output:

```text
game_values.tax_base
```

### Population Value

`population_value` is derived from total population:

```text
population_value = round(10 + 90 * ln(population / min_population) / ln(max_population / min_population))
```

Input:

```text
stats.2022.population.value
```

Output:

```text
game_values.population_value
```

## Current Interpretation

- `tax_base`: abstract tax/economic base for money production.
- `population_value`: abstract population base for manpower, recruitment, and demographic weight.
- Both are balance-friendly game values, not direct real-world figures.

## Regeneration Scripts

Scripts live in `outputs/data_processing_scripts/`.

- `svg_to_provinces.py`: extracts province paths, centers, and inferred neighbors.
- `build_region_maps.py`: builds pre-2016 and post-2016 region groupings.
- `build_province_stats.py`: adds compact Eurostat 2022 population/GDP fields and computes `tax_base` plus `population_value`.
- `build_region_svg.py`: creates the colored SVG basemap used by Godot for region-colored rendering.
