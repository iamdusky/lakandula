class_name CodexEntries
extends RefCounted
## Shared codex data: id -> [title, body]. Used by the in-game CodexPanel
## (event unlocks) and the main-menu HistoricalCodex scene (reads persisted
## unlocks from GameSettings).

const ENTRIES := {
	"lapu_lapu": ["Lapu-Lapu, Datu of Mactan",
		"Lapu-Lapu ruled Mactan when Magellan's fleet reached the Visayas in April 1521. He refused tribute to Spain and to his rival Humabon alike. His stand at Mactan made him the first hero of Philippine resistance."],
	"magellan": ["Ferdinand Magellan",
		"Fernão de Magalhães, a Portuguese navigator in Spanish service, led the first expedition to circumnavigate the globe — though he himself would die on a Mactan beach on April 27, 1521, and never complete the voyage."],
	"humabon": ["Rajah Humabon of Cebu",
		"Humabon welcomed the strangers, accepted baptism as 'Don Carlos', and turned the Spanish alliance against his rivals — chief among them the defiant datu across the strait."],
	"enrique": ["Enrique of Malacca",
		"Magellan's slave and interpreter, seized in Malacca years before. If Enrique reached his birthplace after the fleet fled Cebu, he — not any European — was the first human to circle the world."],
	"conversion": ["The Baptisms of Cebu",
		"In weeks, hundreds of Cebuanos accepted baptism. The image of the Santo Niño presented to Humabon's queen survives today as the oldest Christian relic in the Philippines."],
	"tide": ["The Tide at Mactan",
		"Mactan's fringing reef kept the Spanish ships far offshore at low water. Magellan's men waded in through the surf, in armor, beyond the cover of their own guns — exactly as Lapu-Lapu's warriors intended."],
	"battle_of_mactan": ["The Battle of Mactan",
		"April 27, 1521. Some 49 Spaniards faced perhaps 1,500 Mactan warriors. Magellan burned houses to cow the defenders; instead they pressed the attack at the water's edge, cut him down, and broke the assault."],
	"utang": ["Utang na Loob",
		"A debt of the inner self. Gifts and obligations bound datus, freemen, and allies in webs of reciprocity no conquistador ledger could record — and no gold could repay."],
	"contested_faith": ["The Contested Faith",
		"Baptism at a friar's hand did not erase utang na loob. A datu who took the cross under Spanish guns could still be won back — but a twice-given word carried a far steeper price than the first."],
	"reprisal": ["The Feast of Cebu",
		"Four days after Mactan, Humabon invited the expedition's officers to a banquet of reconciliation. More than two dozen never rose from the table. The survivors cut their cables and fled — whatever Spain's alliance had been, it died with Magellan."],
}
