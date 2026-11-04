class_name ProblemTypes
extends RefCounted
## Every kind of practice problem, in the order the picker shows them.
## To add one: write a script that extends Problem, and add it here.

const ALL := [
	preload("res://practice/problems/hit_speed.gd"),
	preload("res://practice/problems/hit_angle.gd"),
	preload("res://practice/problems/hit_apex.gd"),
	preload("res://practice/problems/two_pigs.gd"),
	preload("res://practice/problems/yellow_tap.gd"),
	preload("res://practice/problems/top_equals_range.gd"),
	preload("res://practice/problems/predict_range.gd"),
	preload("res://practice/problems/predict_apex.gd"),
	preload("res://practice/problems/predict_time.gd"),
	preload("res://practice/problems/other_angle.gd"),
	preload("res://practice/problems/mystery_gravity.gd"),
	preload("res://practice/problems/weight.gd"),
	preload("res://practice/problems/acceleration.gd"),
	preload("res://practice/problems/split_speed.gd"),
	preload("res://practice/problems/split_angle.gd"),
	preload("res://practice/problems/momentum_at_top.gd"),
	preload("res://practice/problems/matilda_kick.gd"),
	preload("res://practice/problems/matilda_straight_down.gd"),
	preload("res://practice/problems/rocket_dv.gd"),
	preload("res://practice/problems/rocket_fuel.gd"),
	preload("res://practice/problems/rocket_acceleration.gd"),
	preload("res://practice/problems/energy_max_height.gd"),
	preload("res://practice/problems/energy_speed_at_height.gd"),
	preload("res://practice/problems/spring_speed.gd"),
	preload("res://practice/problems/spring_pull.gd"),
	preload("res://practice/problems/spring_find_k.gd"),
	preload("res://practice/problems/heavy_vs_light.gd"),
]
