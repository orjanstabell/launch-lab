extends SceneTree
var fails := 0
func ok(name, cond):
	if not cond: fails += 1
	if not cond: print("  FAIL  " + name)
func _initialize():
	await process_frame
	var all_types = load("res://practice/problem_types.gd").ALL
	for script in all_types:
		var sample = script.new()
		var gen_fail = 0
		var judged = 0
		for round in 60:
			var p = script.new()
			p.rng.seed = round * 7919 + 13
			var good = false
			for t in 100:
				if p.generate():
					good = true
					break
			if not good:
				gen_fail += 1
				continue
			ok("%s: question + steps" % p.title, p.question() != "" and p.solution_steps().size() > 0)
			for i in p.answers.size():
				var c = p.correct[i] if p.correct.size() > i else p.correct[0]
				ok("%s: answer %s=%.3f inside input range" % [p.title, p.answers[i]["label"], c], c >= p.answers[i]["min"] and c <= p.answers[i]["max"])
			if p.kind == "predict":
				ok("%s: right answer accepted" % p.title, p.is_correct(p.correct))
				var wrong: Array[float] = []
				for c in p.correct: wrong.append(c * 1.1 + 0.5)
				ok("%s: wrong answer rejected" % p.title, not p.is_correct(wrong))
			else:
				var answers_list := []
				if p.answers.size() == 1 and p.correct.size() > 1:
					for c in p.correct: answers_list.append([c])
				else:
					answers_list.append(p.correct.duplicate())
				for a in answers_list:
					var given: Array[float] = []
					for v in a: given.append(v)
					ok("%s: right answer hits (%s)" % [p.title, given], p.judge(given)["ok"])
				# A clearly wrong answer must miss. (Not just "15% off": near 45° the range
				# barely changes with angle, and two angles hit the same point.)
				var off: Array[float] = []
				if p.answers.size() == 1 and p.correct.size() > 1:
					off.append((p.correct[0] + p.correct[1]) / 2.0)   # between the arcs: passes above
				elif p.answers[0].get("tap", false):
					off.append(p.correct[0] * 0.5)
				else:
					for v in p.correct.slice(0, p.answers.size()): off.append(v * 0.85)
				ok("%s: a clearly wrong answer misses (%s)" % [p.title, off], not p.judge(off)["ok"])
				judged += 1
		print("  %-48s generated %d/60%s" % [sample.title, 60 - gen_fail, ("" if sample.kind == "predict" else ", judged %d" % judged)])
		ok("%s: generates reliably" % sample.title, gen_fail == 0)
	print("DONE, fails=%d" % fails)
	quit(fails)
