.PHONY: get_imports

get_imports:
	cp -r ../JonBallinger-EGSImports/Imports/* SharedFunctions/MemoryRead/Imports/
	dos2unix SharedFunctions/MemoryRead/Imports/*

get_addons_mikebaldi:
	rm -f AddOns/IC_Azaka_Extra/*.ahk AddOns/IC_NERDs_Extra/*.ahk AddOns/IC_NoModronLvling_Extra/*.ahk
	cp -r ../mikebaldi-IC_Addons/IC_Azaka_Extra AddOns
	cp -r ../mikebaldi-IC_Addons/IC_NERDs_Extra AddOns

get_addons_antilectual:
	rm -f AddOns/IC_ConvertBlessings_Mini_Extra/*.ahk AddOns/IC_MoveGameWindow_Mini_Extra/*.ahk
	cp -r ../antilectual-IC_Addons/IC_Addons/IC_ConvertBlessings_Mini_Extra AddOns
	cp -r ../antilectual-IC_Addons/IC_Addons/IC_MoveGameWindow_Mini_Extra AddOns
	# cp -r ../antilectual-IC_Addons/IC_Addons/IC_NoModronAdventuring_Extra AddOns

