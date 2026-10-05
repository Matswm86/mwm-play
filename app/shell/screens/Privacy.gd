extends ShellTextPage

## Privacy text shown in the app, offline, no web link (rules 45, 46).
## Same text as site/privacy/index.html (last updated 5 October 2026).


func _ready() -> void:
	build("Personvern")
	para("Last updated 5 October 2026.")
	heading("What we collect")
	para(
		"Nothing. The MWM Play app does not collect, store or send any personal data to us "
		+ "or to anyone else. It has no accounts, no ads, no analytics and no tracking."
	)
	heading("What stays on the device")
	para(
		"Game progress, such as finished levels and best times, is saved only on the "
		+ "device. Uninstalling the app deletes it."
	)
	heading("Purchases")
	para(
		"The one-time unlock is sold through Google Play Billing. Google handles the "
		+ "payment under its own privacy policy. We never see card details or the buyer's "
		+ "name. Each purchase sits behind a parent gate in the app."
	)
	heading("Children")
	para(
		"The app is made for children. Because it collects no data, it collects no data "
		+ "from children."
	)
	heading("Internet access")
	para(
		"The app connects to the internet only to let Google Play confirm a purchase. "
		+ "The games work offline."
	)
	heading("Changes")
	para("If this policy changes, the new version is posted on this page with a new date.")
	heading("Contact")
	para("mrmaxwilliam@gmail.com")
	end_space()
