extends RefCounted
## Which season and time of day the sky shows (#168), from the device's date,
## clock and region. No rendering: game/sky.gd draws what this picks.
##
## Seasons are meteorological (whole months), flipped for the southern
## hemisphere. There's no location to look up real sunrise and sunset, so
## each season has fixed, typical mid-latitude times instead. Sunrise and
## sunset each last a while either side of the moment itself.

const SEASONS: Array[String] = ["spring", "summer", "fall", "winter"]
const TIMES: Array[String] = ["sunrise", "day", "sunset", "night"]

## Northern-hemisphere season for each month, January first.
const MONTH_SEASONS: Array[String] = [
	"winter", "winter", "spring", "spring", "spring", "summer",
	"summer", "summer", "fall", "fall", "fall", "winter",
]

## Typical sunrise and sunset, in minutes after midnight, by season.
const SUN_TIMES := {
	"spring": Vector2i(6 * 60 + 45, 19 * 60 + 30),
	"summer": Vector2i(5 * 60 + 45, 20 * 60 + 30),
	"fall": Vector2i(7 * 60, 18 * 60 + 45),
	"winter": Vector2i(7 * 60 + 15, 17 * 60),
}
## Sunrise shows from this many minutes before the sun is up until this many
## after; sunset mirrors it.
const GLOW_BEFORE := 30
const GLOW_AFTER := 60

## Region codes (from the locale, e.g. "en_AU") of countries that lie mostly
## south of the equator.
const SOUTHERN_REGIONS: Array[String] = [
	"AR", "AU", "BO", "BR", "BW", "CL", "FJ", "ID", "LS", "MG", "MU", "MW",
	"MZ", "NA", "NC", "NZ", "PE", "PG", "PY", "SZ", "TO", "UY", "WS", "ZA",
	"ZM", "ZW",
]


## The season for a 1-based `month`.
static func season_for(month: int, southern := false) -> String:
	var season := MONTH_SEASONS[clampi(month, 1, 12) - 1]
	if southern:
		season = SEASONS[(SEASONS.find(season) + 2) % SEASONS.size()]
	return season


## The time of day `minutes` after midnight during `season`.
static func time_for(season: String, minutes: int) -> String:
	var sun: Vector2i = SUN_TIMES.get(season, SUN_TIMES["spring"])
	minutes = posmod(minutes, 24 * 60)
	if minutes >= sun.x - GLOW_BEFORE and minutes < sun.x + GLOW_AFTER:
		return "sunrise"
	if minutes >= sun.y - GLOW_AFTER and minutes < sun.y + GLOW_BEFORE:
		return "sunset"
	if minutes >= sun.x and minutes < sun.y:
		return "day"
	return "night"


## Whether a locale such as "en_AU" or "pt-BR" names a southern country.
static func is_southern(locale: String) -> bool:
	var parts := locale.replace("-", "_").split("_")
	for i in range(1, parts.size()):
		if SOUTHERN_REGIONS.has(parts[i].to_upper()):
			return true
	return false


## [season, time of day] for `datetime` (a Time.get_datetime_dict_from_system()
## dictionary) in a country with this `locale`.
static func view_at(datetime: Dictionary, locale: String) -> Array[String]:
	var season := season_for(int(datetime.get("month", 1)), is_southern(locale))
	var minutes := int(datetime.get("hour", 12)) * 60 + int(datetime.get("minute", 0))
	return [season, time_for(season, minutes)]


## [season, time of day] right now, on this device.
static func now() -> Array[String]:
	return view_at(Time.get_datetime_dict_from_system(), OS.get_locale())


## Christmas (#198): Santa flies over the sky from CHRISTMAS_FIRST to
## CHRISTMAS_LAST December, everywhere, whatever the season.
const CHRISTMAS_FIRST := 20
const CHRISTMAS_LAST := 26


## Whether `datetime` (a Time.get_datetime_dict_from_system() dictionary)
## falls at Christmas.
static func is_christmas(datetime: Dictionary) -> bool:
	var day := int(datetime.get("day", 1))
	return int(datetime.get("month", 1)) == 12 and day >= CHRISTMAS_FIRST and day <= CHRISTMAS_LAST


## Whether it's Christmas right now, on this device.
static func christmas_now() -> bool:
	return is_christmas(Time.get_datetime_dict_from_system())
