extends "res://tests/q_test.gd"

const UI := preload("res://game/ui_style.gd")


func test_format_number_leaves_small_numbers_alone() -> void:
	check_eq(UI.format_number(0), "0")
	check_eq(UI.format_number(7), "7")
	check_eq(UI.format_number(999), "999")


func test_format_number_adds_thousands_separators() -> void:
	check_eq(UI.format_number(1000), "1,000")
	check_eq(UI.format_number(5272), "5,272")
	check_eq(UI.format_number(999999), "999,999")
	check_eq(UI.format_number(1000000), "1,000,000")
	check_eq(UI.format_number(1234567), "1,234,567")


func test_format_number_keeps_the_sign_in_front() -> void:
	check_eq(UI.format_number(-5), "-5")
	check_eq(UI.format_number(-999), "-999", "no separator after the sign")
	check_eq(UI.format_number(-1000), "-1,000")
	check_eq(UI.format_number(-1234567), "-1,234,567")
