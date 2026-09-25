# 体育会キャリアラボ - 記事サムネイル自動生成スクリプト
# 使い方: .\scripts\generate-thumbnails.ps1

# キーは環境変数から読み込む（スクリプト実行前に設定してください）
# $env:OPENAI_KEY    = "sk-proj-..."
# $env:MICROCMS_KEY  = "..."
$OPENAI_KEY   = $env:OPENAI_KEY
$MICROCMS_KEY = $env:MICROCMS_KEY
$SERVICE      = "athletecareer"

# 記事リスト（id・プロンプト）
$articles = @(
  @{
    id     = "xz-9a3tijf"
    title  = "転職で強い理由5つ"
    prompt = "A confident young Japanese man in navy business suit shaking hands at a job interview, interviewer across the desk looking impressed, athletic trophy and rising graph in background, warm orange and navy color scheme, clean flat illustration, 16:9, no text"
  },
  @{
    id     = "hj8kadlhacf1"
    title  = "おすすめ職種・業界7選"
    prompt = "A young Japanese man in sports jersey transitioning into a business suit, holding a soccer ball, surrounded by 4 industry icons in circles (real estate, consulting, finance, sports stadium), fresh green and white background, clean flat illustration, 16:9, no text"
  },
  @{
    id     = "ib6gfooewv"
    title  = "自己PRの書き方"
    prompt = "A young Japanese man in business casual confidently presenting at a podium, large speech bubble with trophy and medal icons, purple and light grey background with subtle sports elements, clean flat illustration, 16:9, no text"
  },
  @{
    id     = "qngb71eukxn"
    title  = "エージェントの選び方"
    prompt = "A young Japanese man sitting across from a friendly career advisor at a desk, resume and checklist on table, warm red and cream background, handshake icon above them, clean flat illustration, 16:9, no text"
  },
  @{
    id     = "bt2nt4r5l"
    title  = "3ヶ月スケジュール"
    prompt = "A young Japanese man writing in a planner notebook, 3-month calendar visible on desk, running track fading into background, finish line ribbon, deep blue and yellow background, clean flat illustration, 16:9, no text"
  }
)

function Generate-And-Upload {
  param($article)

  Write-Host "`n[$($article.title)]"

  # --- 1. DALL-E 3 で画像生成 ---
  Write-Host "  画像生成中..."
  $body = [System.Text.Encoding]::UTF8.GetBytes((@{
    model   = "dall-e-3"
    prompt  = $article.prompt
    size    = "1792x1024"
    quality = "standard"
    n       = 1
  } | ConvertTo-Json -Compress))

  try {
    $res = Invoke-RestMethod `
      -Uri "https://api.openai.com/v1/images/generations" `
      -Method POST `
      -Headers @{ "Authorization" = "Bearer $OPENAI_KEY"; "Content-Type" = "application/json" } `
      -Body $body
  } catch {
    Write-Host "  画像生成失敗: $_" -ForegroundColor Red
    return
  }

  $imageUrl = $res.data[0].url
  Write-Host "  生成完了 ✓"

  # --- 2. 画像をダウンロード ---
  $tmpFile = [System.IO.Path]::Combine($env:TEMP, "$($article.id).png")
  Invoke-WebRequest -Uri $imageUrl -OutFile $tmpFile | Out-Null
  Write-Host "  ダウンロード完了 ✓"

  # --- 3. MicroCMS メディアAPIにアップロード ---
  Write-Host "  MicroCMSにアップロード中..."
  $httpClient = New-Object System.Net.Http.HttpClient
  $httpClient.DefaultRequestHeaders.Add("X-MICROCMS-API-KEY", $MICROCMS_KEY)

  $multipart = New-Object System.Net.Http.MultipartFormDataContent
  $fileBytes = [System.IO.File]::ReadAllBytes($tmpFile)
  $byteContent = New-Object System.Net.Http.ByteArrayContent($fileBytes)
  $byteContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("image/png")
  $multipart.Add($byteContent, "file", "$($article.id).png")

  $uploadRes = $httpClient.PostAsync("https://$SERVICE.microcms.io/api/v1/media", $multipart).Result
  $uploadJson = $uploadRes.Content.ReadAsStringAsync().Result | ConvertFrom-Json
  $mediaUrl = $uploadJson.url

  if (-not $mediaUrl) {
    Write-Host "  アップロード失敗: $($uploadRes.StatusCode)" -ForegroundColor Red
    return
  }
  Write-Host "  アップロード完了 ✓ $mediaUrl"

  # --- 4. 記事のサムネイルを更新 ---
  $patchBody = [System.Text.Encoding]::UTF8.GetBytes((@{
    thumbnail = @{ url = $mediaUrl }
  } | ConvertTo-Json -Compress))

  Invoke-RestMethod `
    -Uri "https://$SERVICE.microcms.io/api/v1/columns/$($article.id)" `
    -Method PATCH `
    -Headers @{ "X-MICROCMS-API-KEY" = $MICROCMS_KEY } `
    -Body $patchBody `
    -ContentType "application/json; charset=utf-8" | Out-Null

  Write-Host "  サムネイルセット完了 ✓" -ForegroundColor Green

  # 一時ファイル削除
  Remove-Item $tmpFile -ErrorAction SilentlyContinue
}

# 全記事を処理
foreach ($article in $articles) {
  Generate-And-Upload $article
}

Write-Host "`n全記事のサムネイル生成・アップロード完了！" -ForegroundColor Green
