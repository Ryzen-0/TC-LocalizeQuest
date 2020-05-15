$PSDefaultParameterValues['*:Encoding'] = 'utf8';

# https://it.wowhead.com/sunstrider-isle-quests
$url_toParse = Read-Host -Prompt 'Enter the URL of the quest zone to be parsed (es. https://it.wowhead.com/sunstrider-isle-quests)';

$prova = $url_toParse -match 'http[s]*\:\/\/([\w]+).*\/([\w\-]+)';

$zone_lang = $Matches[1];
$zone_name = $Matches[2];
$langcode = "";

# if zone file does not exists ("zonename-lang.sql")
$file_toSave = "$($zone_name)-$($zone_lang).sql";
if( -not( Test-Path -LiteralPath $file_toSave -PathType Leaf)) {
	New-Item $file_toSave;
} else {
	Remove-Item $file_toSave;
}

switch( $zone_lang ) {
    "it" {
		$langcode = "itIT";
	}
    "es" {
		$langcode = "esES";
	}
    "fr" {
		$langcode = "frFR";
	}
    "de" {
		$langcode = "deDE";
	}
}


$url = Invoke-WebRequest -UseBasicParsing $url_toParse;

$temp = $url.Content -match 'data:\[(.+)\]';

$quests_toParse = $Matches[1];

$quests_toParse -replace "'","___" | Select-String -Pattern '\{[\w\"\:\, \[\]\-]+\"id\"\:([\d]+)[\w\"\:\, \[\]\-]+\"name"\:\"([\w\s\!\\\:\-]+)\"[\w\"\:\, \[\]\-]+\}' -AllMatches | 
ForEach-Object {$_.Matches} |
ForEach-Object {
	$quest_id = $_.Groups[1].Value;
	$quest_name = $_.Groups[2].Value;
	
	if( $quest_id -And $quest_name ) {
		echo "$($quest_id)|$($quest_name)";

		# https://it.wowhead.com/quest=8326
		$url_toParse = "https://$($zone_lang).wowhead.com/quest=$($quest_id)";

		$quest_toParse = $url_toParse -match 'http(s)*\:\/\/([\w]*){2}(\.*)(.*)quest\=([\d]+).*';
		$quest_id = $Matches[5];
		
		if( !$quest_id ) {
			echo "Quest ID could not be parsed";
			Read-Host -Prompt "Press Enter to exit";
		}
		
		$url = Invoke-WebRequest -UseBasicParsing $url_toParse;

		$quest_progress = $url.Content -match '\<div id="lknlksndgg-progress"([\w = \"\:\;\<\>\/]*)\>(.+)';
		if( $Matches[2] ) {
			# replace some special characters
			$quest_progress_text = $Matches[2] -replace "'", "\'" -replace "___","\'" -replace "&lt;","<" -replace "&gt;",">" -replace "&nbsp;","" -replace "<name>",'$n' -replace "<class>",'$c' -replace "<race>",'$r' -replace "<br([\s]/*)>","`n";
		
			Add-Content $file_toSave "";
			Add-Content $file_toSave "-- $($quest_name)";
			Add-Content $file_toSave "DELETE FROM quest_request_items_locale WHERE ID=$($quest_id) AND locale='$($langcode)';";
			Add-Content $file_toSave "INSERT INTO quest_request_items_locale (ID, locale, CompletionText, VerifiedBuild) VALUES ($($quest_id), '$($langcode)', '$($quest_progress_text)', 0);";
		}
		
		$quest_completition = $url.Content -match '\<div id="lknlksndgg-completion"([\w = \"\:\;\<\>\/]*)\>(.+)';
		if( $Matches[2] ) {
			# replace some special characters
			$quest_completition_text = $Matches[2] -replace "'", "\'" -replace "___","\'" -replace "&lt;","<" -replace "&gt;",">" -replace "&nbsp;","" -replace "<name>",'$n' -replace "<class>",'$c' -replace "<race>",'$r' -replace "<br([\s]/*)>","`n";

			Add-Content $file_toSave "";
			Add-Content $file_toSave "-- $($quest_name)";
			Add-Content $file_toSave "DELETE FROM quest_offer_reward_locale WHERE ID=$($quest_id) AND locale='$($langcode)';";
			Add-Content $file_toSave "INSERT INTO quest_offer_reward_locale (ID, locale, RewardText, VerifiedBuild) VALUES ($($quest_id), '$($langcode)', '$($quest_completition_text)', 0);";
		}

		
	}
}

# reload all locales