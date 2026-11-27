extends RefCounted
## One stretch of perf samples for one screen (#321), summed up for the
## perf monitor's log: averages of every field, plus the 95th percentile and
## the worst frame for the frame and process times, where stutters show.

## Every field a sample carries, in log order. Times are in milliseconds:
## frame_ms from one frame to the next (the frame cap included), process_ms
## the nodes' _process work, busy_ms everything the CPU does for the frame
## (process, drawing and handing the frame to the GPU), and the viewports'
## CPU and GPU render times.
const FIELDS: Array[String] = [
	"frame_ms",
	"process_ms",
	"busy_ms",
	"draw_calls",
	"primitives",
	"root_cpu_ms",
	"root_gpu_ms",
	"tower_cpu_ms",
	"tower_gpu_ms",
	"target_fps",
	"memory_mb",
]
## Fields that also get a p95 and a max.
const SPREAD_FIELDS: Array[String] = ["frame_ms", "process_ms", "busy_ms"]

var scene := ""
## Field name to an Array of floats. Not packed arrays: those are copied on
## the way out of a Dictionary, so appending to one would be lost.
var _values := {}


func _init(for_scene := "") -> void:
	scene = for_scene
	for field in FIELDS:
		_values[field] = []


## Adds one frame's sample: a Dictionary of FIELDS to numbers. Missing
## fields count as 0.
func add(sample: Dictionary) -> void:
	for field in FIELDS:
		(_values[field] as Array).append(float(sample.get(field, 0.0)))


func frames() -> int:
	return (_values[FIELDS[0]] as Array).size()


func is_empty() -> bool:
	return frames() == 0


## The stretch summed up: scene, frames, seconds, fps, then `<field>` (the
## average) for every field, and `<field>_p95` and `<field>_max` for
## SPREAD_FIELDS.
func summary() -> Dictionary:
	var out := {"scene": scene, "frames": frames()}
	var frame_times := PackedFloat32Array(_values["frame_ms"])
	var seconds := _sum(frame_times) / 1000.0
	out["seconds"] = seconds
	out["fps"] = frames() / seconds if seconds > 0.0 else 0.0
	for field in FIELDS:
		var values := PackedFloat32Array(_values[field])
		out[field] = _sum(values) / values.size() if values.size() > 0 else 0.0
		if field in SPREAD_FIELDS:
			out[field + "_p95"] = percentile(values, 0.95)
			out[field + "_max"] = percentile(values, 1.0)
	return out


## The CSV columns, after the time and device columns the monitor adds.
static func columns() -> Array[String]:
	var out: Array[String] = ["scene", "frames", "seconds", "fps"]
	for field in FIELDS:
		out.append(field)
		if field in SPREAD_FIELDS:
			out.append(field + "_p95")
			out.append(field + "_max")
	return out


## `summary` (from summary()) as CSV cells in columns() order.
static func csv_cells(summary: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for column in columns():
		var value = summary.get(column, "")
		if value is String or value is int:
			out.append(str(value))
		else:
			out.append("%.3f" % float(value))
	return out


## One console line: the numbers worth glancing at while playing.
static func describe(s: Dictionary) -> String:
	return (
		(
			"%s %.1fs %.0ffps (cap %.0f) frame %.1f/%.1f/%.1fms process %.2f/%.2fms"
			+ " busy %.2f/%.2fms draws %.0f prims %.0f render cpu %.2f gpu %.2fms tower cpu %.2f gpu %.2fms"
		)
		% [
			s.scene,
			s.seconds,
			s.fps,
			s.target_fps,
			s.frame_ms,
			s.frame_ms_p95,
			s.frame_ms_max,
			s.process_ms,
			s.process_ms_p95,
			s.busy_ms,
			s.busy_ms_p95,
			s.draw_calls,
			s.primitives,
			s.root_cpu_ms,
			s.root_gpu_ms,
			s.tower_cpu_ms,
			s.tower_gpu_ms,
		]
	)


## The value `share` (0 to 1) of the way up `values` once sorted; 1 is the
## largest. 0 when empty.
static func percentile(values: PackedFloat32Array, share: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var index := clampi(ceili(share * sorted.size()) - 1, 0, sorted.size() - 1)
	return sorted[index]


static func _sum(values: PackedFloat32Array) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total
