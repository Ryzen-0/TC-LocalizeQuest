$PSDefaultParameterValues['*:Encoding'] = 'utf8'; # no need for PowerShell 7+

function Get-GTranslate {

    Param( [string]$textToTranslate, [string]$intoLang )

    $textToTranslate = [System.Web.HttpUtility]::UrlEncode( $textToTranslate );

	$Uri = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=$($intoLang)&dt=t&q=$textToTranslate";
	
	$Response = Invoke-WebRequest -UseBasicParsing -Uri $Uri -Method Get;
	$RispostaJSON = $Response.Content | ConvertFrom-Json;
    # $RispostaJSON = Get-Content -Path "esempio.json" | ConvertFrom-Json; # debug
	
    $textTranslated = "";
    $RispostaJSON[0] | ForEach-Object -Process {

        $x = 0;

        $_ | ForEach-Object -Process {

            if( $x -gt 0 ) {
                return;
            }

            $textTranslated += $_;

            $x++;
        };

        return;
    };

	$OrigLangCode = $RispostaJSON[2];

	# fix returned string
	$textTranslated = $textTranslated -replace "\\", "" -replace "'", "\'" -replace '\$ n', '$n' -replace '\$ c', '$c' -replace '\$ r', '$r';
    
	return $textTranslated, $OrigLangCode;
}

# https://it.wowhead.com/sunstrider-isle-quests
$url_toParse = Read-Host -Prompt 'Enter the URL of the quest zone to be parsed (es. https://it.wowhead.com/quests/eastern-kingdoms/sunstrider-isle)';

$url_toParse -match 'http[s]*\:\/\/([\w]+).*\/([\w\-]+)[\#]*(.*)';

$zone_lang = $Matches[1];
$zone_name = $Matches[2];
$url_filters = $Matches[3];
$langcode = "";

# if zone file does not exists ("zonename-lang.sql")
$file_toSave = "$($zone_name)-$($zone_lang)$($url_filters).sql";
$file_toSave_gTranslate = "$($zone_name)-$($zone_lang)$($url_filters)-gtranslate.sql";

if( -not( Test-Path -LiteralPath $file_toSave -PathType Leaf)) {
	New-Item $file_toSave;
} else {
	Remove-Item $file_toSave;
	Remove-Item $file_toSave_gTranslate;
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

$url.Content -match 'data:\[(.+)\]';

$quests_toParse = $Matches[1];

$quests_toParse -replace "'","___" | Select-String -Pattern '\{[\w\"\:\, \[\]\-]+\"id\"\:([\d]+)[\w\"\:\, \[\]\-]+\"name"\:\"([\w\s\!\\\:\-\[\]]+)\"[\w\"\:\, \[\]\-]+\}' -AllMatches | 
ForEach-Object {$_.Matches} |
ForEach-Object {
	$quest_id = $_.Groups[1].Value;
	$quest_name = $_.Groups[2].Value;
	
	if( $quest_id -And $quest_name ) {
		Write-Output "$($quest_id)|$($quest_name)";

		# https://it.wowhead.com/quest=8326
		$url_toParse = "https://$($zone_lang).wowhead.com/quest=$($quest_id)";

		Write-Output "$($url_toParse)"; # debug
		Write-Output "";

		$url_toParse -match "http(s)*\:\/\/([\w]*){2}(\.*)(.*)quest\=([\d\']+).*";
		$quest_id = $Matches[5];
		
		if( !$quest_id ) {
			Write-Output "Quest ID could not be parsed";
			Read-Host -Prompt "Press Enter to exit";
		}
		
		$url = Invoke-WebRequest -UseBasicParsing $url_toParse;

		# quest progress regexp
		$url.Content -match '\<div id="lknlksndgg-progress"([\w = \"\:\;\<\>\/]*)\>(.+)';
		$quest_progress = $Matches[2];

		# quest completition regexp
		$url.Content -match '\<div id="lknlksndgg-completion"([\w = \"\:\;\<\>\/]*)\>(.+)';
		$quest_completition = $Matches[2];

		$prev_saveFile = "";

		if( $quest_progress ) {
			# replace some special characters
			$quest_progress_text = $quest_progress -replace "'", "\'" -replace "___","\'" -replace "&lt;","<" -replace "&gt;",">" -replace "&nbsp;","" -replace "<name>",'$n' -replace "<class>",'$c' -replace "<race>",'$r' -replace "<br([\s]/*)>","`n";
			
			# BEGIN translate
			Start-Sleep -s 15; # to avoid temporary ip ban
			$parsedQuest = Get-GTranslate $quest_progress_text $zone_lang;
			# END translate
		
			if( $parsedQuest[1] -ne $zone_lang ) {
				# google translated text as fallback
				$quest_progress_text = $parsedQuest[0];
				$targetFile = $file_toSave_gTranslate;
			} else {
				# official text
				$targetFile = $file_toSave;
			}

			if( $prev_saveFile -ne $targetFile ) {
				$prev_saveFile = $targetFile;

				if( $quest_progress ) {

					$quest_name = $quest_name -replace "___", "'";
		
					Add-Content $targetFile "";
					Add-Content $targetFile "-- $($quest_name)";
				} else {
					Add-Content $targetFile "";
					Add-Content $targetFile "-- $($quest_name) | SKIP";
				}
			}

			Add-Content $targetFile "DELETE FROM quest_request_items_locale WHERE ID=$($quest_id) AND locale='$($langcode)';";
			Add-Content $targetFile "INSERT INTO quest_request_items_locale (ID, locale, CompletionText, VerifiedBuild) VALUES ($($quest_id), '$($langcode)', '$($quest_progress_text)', 0);";
		}
		
		if( $quest_completition ) {
			# replace some special characters
			$quest_completition_text = $quest_completition -replace "'", "\'" -replace "___","\'" -replace "&lt;","<" -replace "&gt;",">" -replace "&nbsp;","" -replace "<name>",'$n' -replace "<class>",'$c' -replace "<race>",'$r' -replace "<br([\s]/*)>","`n";
			
			# BEGIN translate
			Start-Sleep -s 15; # to avoid temporary ip ban
			$parsedQuest = Get-GTranslate $quest_completition_text $zone_lang;
			# END translate

			if( $parsedQuest[1] -ne $zone_lang ) {
				# google translated text as fallback
				$quest_completition_text = $parsedQuest[0];
				$targetFile = $file_toSave_gTranslate;
			} else {
				# official text
				$targetFile = $file_toSave;
			}


			if( $prev_saveFile -ne $targetFile ) {
				$prev_saveFile = $targetFile;

				if( $quest_completition ) {

					$quest_name = $quest_name -replace "___", "'";
		
					Add-Content $targetFile "";
					Add-Content $targetFile "-- $($quest_name)";
				} else {
					Add-Content $targetFile "";
					Add-Content $targetFile "-- $($quest_name) | SKIP";
				}
			}

			Add-Content $targetFile "DELETE FROM quest_offer_reward_locale WHERE ID=$($quest_id) AND locale='$($langcode)';";
			Add-Content $targetFile "INSERT INTO quest_offer_reward_locale (ID, locale, RewardText, VerifiedBuild) VALUES ($($quest_id), '$($langcode)', '$($quest_completition_text)', 0);";
		}

		$prev_saveFile = "";
	}
}

# reload all locales

Read-Host -Prompt "Press Enter to exit"
