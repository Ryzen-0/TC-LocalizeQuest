# $PSDefaultParameterValues['*:Encoding'] = 'utf8'; # no need for PowerShell 7+

$cont = 0;
$zone_lang = "it";
$file_toSave = "export-to-db.sql";
$nAtOnce = 5;

$last_quest_file = "lastquest_id.txt";
$resumeFrom_questID = 0;

if( Test-Path $last_quest_file ) {
    $resumeFrom_questID = Get-Content $last_quest_file;
} else {
    Remove-Item $file_toSave;
}

$csvToImport = Get-ChildItem -Filter *.csv | Select-Object -First 1 | ForEach-Object { $_.Name; };

Import-Csv $csvToImport |`
    ForEach-Object {

        $quest_id = $_.globalID
    
        if( $resumeFrom_questID -gt 0 -and $resumeFrom_questID -ne $quest_id ) {
            
            Write-Output "$quest_id|SKIP";
            return;
        } else {
            $resumeFrom_questID = 0;
            Write-Output "$quest_id";
        }

        if( $cont -ge $nAtOnce ) {
            Set-Content -Path $last_quest_file -Value $quest_id;
            break;
        }

		# https://it.wowhead.com/quest=8326
		$url_toParse = "https://$($zone_lang).wowhead.com/quest=$($quest_id)";

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

		$url_toParse -match "http(s)*\:\/\/([\w]*){2}(\.*)(.*)quest\=([\d\']+).*";
		$quest_id = $Matches[5];
		
		if( !$quest_id ) {
			Write-Output "Quest ID could not be parsed";
			Read-Host -Prompt "Press Enter to exit";
		}
		
		$url = Invoke-WebRequest -UseBasicParsing $url_toParse;

        # quest name
        $url.Content -match '\<h1.*\>(.*)\<\/h1\>';
        $quest_name = $Matches[1];

        Write-Output $quest_name;
        Write-Output "$($url_toParse)"; # debug
        Write-Output "";

		# quest progress regexp
		$url.Content -match '\<div id="lknlksndgg-progress"([\w = \"\:\;\<\>\/]*)\>(.+)';
		$quest_progress = $Matches[2];

		# quest completition regexp
		$url.Content -match '\<div id="lknlksndgg-completion"([\w = \"\:\;\<\>\/]*)\>(.+)';
		$quest_completition = $Matches[2];

		if( $quest_progress -or $quest_completition ) {
			Add-Content $file_toSave "";
			Add-Content $file_toSave "-- $($quest_name)";
		} else {
			Add-Content $file_toSave "";
			Add-Content $file_toSave "-- $($quest_name) | SKIP";
		}

		if( $quest_progress ) {
			# replace some special characters
			$quest_progress_text = $quest_progress -replace "'", "\'" -replace "___","\'" -replace "&lt;","<" -replace "&gt;",">" -replace "&nbsp;","" -replace "<name>",'$n' -replace "<class>",'$c' -replace "<race>",'$r' -replace "<br([\s]/*)>","`n";
		
			Add-Content $file_toSave "DELETE FROM quest_request_items_locale WHERE ID=$($quest_id) AND locale='$($langcode)';";
			Add-Content $file_toSave "INSERT INTO quest_request_items_locale (ID, locale, CompletionText, VerifiedBuild) VALUES ($($quest_id), '$($langcode)', '$($quest_progress_text)', 0);";
		}
		
		if( $quest_completition ) {
			# replace some special characters
			$quest_completition_text = $quest_completition -replace "'", "\'" -replace "___","\'" -replace "&lt;","<" -replace "&gt;",">" -replace "&nbsp;","" -replace "<name>",'$n' -replace "<class>",'$c' -replace "<race>",'$r' -replace "<br([\s]/*)>","`n";

			Add-Content $file_toSave "DELETE FROM quest_offer_reward_locale WHERE ID=$($quest_id) AND locale='$($langcode)';";
			Add-Content $file_toSave "INSERT INTO quest_offer_reward_locale (ID, locale, RewardText, VerifiedBuild) VALUES ($($quest_id), '$($langcode)', '$($quest_completition_text)', 0);";
		}

        $cont++;
    }


