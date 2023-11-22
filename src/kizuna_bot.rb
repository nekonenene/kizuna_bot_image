require "discordrb"
require "net/http"
require "rest-client"
require "uri"
require "json"
require "dotenv"

Dotenv.load("../.env")

class KizunaBot
  attr_accessor :bot

  BOT_CLIENT_ID = ENV["BOT_CLIENT_ID"].freeze
  BOT_TOKEN = ENV["BOT_TOKEN"].freeze

  LIVEDOOR_WEATHER_API_HOST = "http://weather.livedoor.com/forecast/webservice/json/v1".freeze
  TOKYO_CITY_ID = 130010

  RSS2JSON_API_HOST = "https://api.rss2json.com/v1/api.json".freeze
  RSS2JSON_API_KEY = ENV["RSS2JSON_API_KEY"].freeze
  HATENA_HOTENTRY_RSS = "http://b.hatena.ne.jp/hotentry?mode=rss".freeze

  HOT_PEPPER_API_HOST = "http://webservice.recruit.co.jp/hotpepper/gourmet/v1".freeze
  RECRUIT_API_KEY = ENV["RECRUIT_API_KEY"].freeze

  CUSTOM_SEARCH_API_HOST = "https://www.googleapis.com/customsearch/v1".freeze
  CUSTOM_SEARCH_ENGINE_ID = ENV["CUSTOM_SEARCH_ENGINE_ID"].freeze
  CUSTOM_SEARCH_API_KEY = ENV["CUSTOM_SEARCH_API_KEY"].freeze

  YOUTUBE_DATA_API_HOST = "https://www.googleapis.com/youtube/v3".freeze
  YOUTUBE_DATA_API_KEY = ENV["YOUTUBE_DATA_API_KEY"].freeze

  RANK_TOTAL_COUNT = 200 # 発言数集計のために取得する件数

  GOOGLE_TRANSLATE_API_HOST = "https://script.google.com/macros/s/AKfycbzX3hgwpkCG-q-47nvu9CpeGXJ2uoQVbAngwNpbHjx6jCiOMXE/exec".freeze

  def initialize
    @bot = Discordrb::Commands::CommandBot.new(token: BOT_TOKEN, client_id: BOT_CLIENT_ID, prefix: "/")
  end

  def start
    puts "This bot's invite URL is #{@bot.invite_url}"
    puts "Click on it to invite it to your server."

    settings

    @bot.run
  end

  def settings
    ### メンションに反応 ###
    @bot.mention do |event|
      message = message_without_mentions(event)

      reply = munou_message(message: message, event: event)
      event.respond(reply) unless reply.nil?
    end

    ### Ping ###
    @bot.command(:ping) do |event|
      m = event.respond("Pong！")
      m.edit "Pong！ 応答までに #{Time.now - event.timestamp} 秒かかったよ！"
    end

    ### ニュース ###
    @bot.command(:news) do |event|
      event.respond(news_message)
    end

    ### 天気 ###
    @bot.message(contains: /天気は？$/) do |event|
      return if event.message.mentions.count > 0
      event.respond(weather_message)
    end

    @bot.command(:weather) do |event|
      event.respond(weather_message)
    end

    ### サイコロ ###
    @bot.command(:dice) do |event, max|
      event.respond(dice_message(max: max))
    end

    ### 料理屋さん検索 ###
    @bot.command(:gourmet, aliases: [:gurume, :grm]) do |event, address, keyword|
      event.respond(gourmet_message(address: address, keyword: keyword))
    end

    @bot.message(contains: /^(おなかすいた|おなすき)/) do |event|
      if match_data = event.content.match(/^([^、,]+)、([^、,]+)、?(.+)?$/)
        address = match_data[2]
        keyword = match_data[3]
        event.respond(gourmet_message(address: address, keyword: keyword))
      else
        event.respond(gourmet_message)
      end
    end

    ### image ###
    @bot.command(:image, aliases: [:img]) do |event, *queries|
      query = queries.join(" ")
      event.respond(image_message(query: query))
    end

    ### rank ###
    @bot.command(:rank) do |event|
      channel = event.channel # Discordrb::Channel
      event.respond(user_rank_message(channel: channel))
    end

    ### translate ###
    @bot.command(:eng) do |event, *queries|
      text = queries.join(" ")
      event.respond(translate_message(text: text, target_lang: "en"))
    end

    @bot.command(:jpn, aliases: [:jap]) do |event, *queries|
      text = queries.join(" ")
      event.respond(translate_message(text: text, target_lang: "ja"))
    end

    ### video ###
    @bot.command(:video, aliases: [:youtube]) do |event, *queries|
      query = queries.join(" ")
      event.respond(video_search_message(query: query))
    end

    @bot.command(:vtuber) do |event, *queries|
      query = "VTuber " + queries.join(" ")
      event.respond(video_search_message(query: query))
    end

    ### help ###
    @bot.command(:help) do |event|
      event.respond(help_message)
    end
  end

  def news_message
    max_links = 50 # このRSSの最大は 30 件の様子
    encoded_rss_url = URI.encode(HATENA_HOTENTRY_RSS)
    uri = URI.parse("#{RSS2JSON_API_HOST}?rss_url=#{encoded_rss_url}&api_key=#{RSS2JSON_API_KEY}&count=#{max_links}")
    response = Net::HTTP.get_response(uri)
    res_json = JSON.parse(response.body)

    items = res_json["items"]
    links = items.map{|item| item["link"]}

    random_link = links.sample

    "ニュースのお届けだよー！ ガシーン ヽ(•̀ω•́ )ゝ\n#{random_link}"
  end

  def weather_message
    uri = URI.parse("#{LIVEDOOR_WEATHER_API_HOST}?city=#{TOKYO_CITY_ID}")
    response = Net::HTTP.get_response(uri)
    res_json = JSON.parse(response.body)

    point_locations = res_json["pinpointLocations"]
    shibuyaku = point_locations.select{ |location|
      location["name"].include?("渋谷区")
    }&.first
    shibuyaku_link = shibuyaku["link"] unless shibuyaku.nil?

    city = res_json.dig("location", "city")
    forecasts = res_json["forecasts"]

    message = ""
    forecasts.each{ |f|
      max_temperature = f.dig("temperature", "max", "celsius")
      message += "#{f["dateLabel"]}（#{f["date"]}）の#{city}の天気は「#{f["telop"]}」"
      message += "、最高気温は#{max_temperature}℃" unless max_temperature.nil?
      message += "\n"
    }
    message += "詳しくはこちら → #{shibuyaku_link}"
  end

  def dice_message(max: nil)
    max ||= 6 # 指定がなければ6面ダイス
    max = max.to_i.abs
    val = rand(1..max)
    "#{max}面サイコロを回したら、「#{val}」が出たよ！"
  end

  def gourmet_message(address: nil, keyword: nil)
    default_address = "渋谷駅"
    address ||= default_address
    keyword.gsub!(/(,|、)/, " ") unless keyword.nil?
    max_count = 100

    query_str  = "key=#{RECRUIT_API_KEY}"
    query_str += "&address=#{address}"
    query_str += "&keyword=#{keyword}" unless keyword.nil?
    query_str += "&count=#{max_count}"
    query_str += "&format=json"

    encoded_query = URI.encode(query_str)

    uri = URI.parse("#{HOT_PEPPER_API_HOST}?#{encoded_query}")
    response = Net::HTTP.get_response(uri)
    res_json = JSON.parse(response.body)

    shop_list = res_json.dig("results", "shop")
    return "ごめんね、お店見つけられなかったよ……" if shop_list.empty?

    shop_info = shop_list.sample

    message  = "#{address}で探してみたよ！ こことかどうかなー！\n"
    message += "#{shop_info["mobile_access"]} 『#{shop_info["name"]}』\n"
    message += shop_info.dig("urls", "pc")
  end

  def image_message(query: nil)
    return "検索ワードがないよ？ 『/image ねこ』みたいに書いてね！" if query.nil?

    query.gsub!(/(,|、)/, " ")
    max_count = 10 # 10件が最大の様子

    query_str  = "key=#{CUSTOM_SEARCH_API_KEY}"
    query_str += "&cx=#{CUSTOM_SEARCH_ENGINE_ID}"
    query_str += "&q=#{query}"
    query_str += "&hl=ja"
    query_str += "&searchType=image"
    query_str += "&num=#{max_count}"

    encoded_query = URI.encode(query_str)

    uri = URI.parse("#{CUSTOM_SEARCH_API_HOST}?#{encoded_query}")
    response = Net::HTTP.get_response(uri)
    res_json = JSON.parse(response.body)

    items = res_json["items"]
    return "画像が見つからなかったよー" if items.nil? || items.empty?

    links = items.map{|item| item["link"]}
    image_link = links.sample

    message  = "画像のお届けですよ〜 ヾﾉ｡ÒㅅÓ)ﾉｼ”\n"
    message += image_link
  end

  def user_rank_message(channel: nil)
    return nil if channel.nil?

    max_count = RANK_TOTAL_COUNT
    max_per_page = 100 # APIの仕様上ページあたりは100件まで
    remain = max_count

    messages = []

    oldest_message_id = nil
    while remain > 0 do
      response = Discordrb::API::Channel.messages(BOT_TOKEN, channel.id, (remain < max_per_page) ? remain : max_per_page, oldest_message_id)

      res_json = JSON.parse(response)
      break if res_json.empty?

      oldest_message_id = res_json.last["id"]
      messages += res_json
      remain -= max_per_page
    end

    user_and_post_count = Hash.new

    messages.each{ |message|
      post_user = message["author"]["username"]

      if user_and_post_count[post_user].nil?
        user_and_post_count[post_user] = 1
      else
        user_and_post_count[post_user] += 1
      end
    }

    user_and_post_count = user_and_post_count.sort_by{|key, val| -val}.to_h
    amount = user_and_post_count.values.sum
    top_five = user_and_post_count.first(5)

    message = "ヒマな人ランキング in <##{channel.id}> だよ！ "
    message += %W(人生は有意義にね！ 楽しそうだね！ 目指すならトップだよね！ ねえねえ、仕事は？ 最新#{amount}件の結果だよ！ この人たちに話しかけよう！ 他にやることないんだね〜 かわいいね！ これが最強戦士……！).sample
    message += "\n"

    top_five.each_with_index{ |item, idx|
      message +=
        case idx
        when 0
          ":first_place: "
        when 1
          ":second_place: "
        when 2
          ":third_place: "
        else
          ""
        end
      username = item[0]
      post_count = item[1]
      message += "#{idx + 1}. #{username} (#{post_count}: #{(post_count.to_f / amount * 100).round(2)}%)\n"
    }
    message
  end

  def translate_message(text: nil, target_lang: nil)
    return if text.nil?
    target_lang ||= "en"

    query_str  = "text=#{text}"
    query_str += "&target=#{target_lang}"

    encoded_query = URI.encode(query_str)

    response = RestClient.get("#{GOOGLE_TRANSLATE_API_HOST}?#{encoded_query}")

    message  = "翻訳してみたよ！\n"
    message += "「#{response.body}」 これでどうかな？ σ(．_．@)"
  end

  def video_search_message(query: nil)
    video_url = random_video_url_by_query(query: query)
    return "いい動画が見つけられなかったよ、ごめんね" if video_url.nil?

    message  = (!query.nil? && !query.empty?) ? "『#{query}』の" : "最近の"
    message += "動画を探してきたよ！ ( ⁎ᵕᴗᵕ⁎ ) :heartbeat:\n"
    message += video_url
  end

  def random_video_url_by_channel(channel_id: nil)
    return if channel_id.nil?

    query_str  = "key=#{YOUTUBE_DATA_API_KEY}"
    query_str += "&part=id"
    query_str += "&type=video"
    query_str += "&channelId=#{channel_id}"
    query_str += "&maxResults=50"
    query_str += "&order=date"

    encoded_query = URI.encode(query_str)

    response = RestClient.get("#{YOUTUBE_DATA_API_HOST}/search?#{encoded_query}")
    res_json = JSON.parse(response)
    items = res_json["items"]
    return nil if items.empty?
    video_id = items.sample.dig("id", "videoId")

    "https://www.youtube.com/watch?v=#{video_id}"
  end

  def random_video_url_by_query(query: nil)
    query_str  = "key=#{YOUTUBE_DATA_API_KEY}"
    query_str += "&part=id"
    query_str += "&type=video"
    query_str += "&q=#{query}" if !query.nil? && !query.empty?
    query_str += "&maxResults=50"
    query_str += "&order=date"
    query_str += "&regionCode=JP"

    encoded_query = URI.encode(query_str)

    response = RestClient.get("#{YOUTUBE_DATA_API_HOST}/search?#{encoded_query}")
    res_json = JSON.parse(response)
    items = res_json["items"]
    return nil if items.empty?
    video_id = items.sample.dig("id", "videoId")

    "https://www.youtube.com/watch?v=#{video_id}"
  end

  def help_message
    message  = "/weather : 天気を教えるよ〜 :white_sun_small_cloud:\n"
    message += "/news : 話題の記事をお届けしちゃうよ！ 暇な時はこれ！ :newspaper:\n"
    message += "/gurume, /grm : お料理屋さんを探すよ、「/gurume 新宿 焼肉,個室,食べ放題」みたいに使ってね。カンマは「、」でもOK！ :fork_knife_plate:\n"
    message += "/image, /img : いい写真を見つけてくるよ！ 1日100回までしか検索できないみたい… :art:\n"
    message += "/dice : サイコロを回すよ。引数があると、それを最大値とするサイコロを回すよ :game_die:\n"
    message += "/rank : 最近ヒマそうにしてる人を教えてあげるね :kiss_ww:\n"
    message += "/eng : 英語でなんて言うのかがんばって翻訳するよ！ :capital_abcd:\n"
    message += "/jpn : 日本語でどう言うのか考えるよ！ :flag_jp:\n"
    message += "/video, /youtube : YouTubeから動画を探してくるよ！ 「/video ゲーム実況」みたいに使ってね :arrow_forward:\n"
    message += "/vtuber : VTuberさんの動画を探してくるよ！ :dancer:\n"
    message += "/ping : テスト用だよ\n"
    message += "/help : これだよ\n"
  end

  def munou_message(message: nil, event: nil)
    case message
    when /英語で/
      if match_data = event.content.match(/「(.+)」/)
        text = match_data[1]
        translate_message(text: text, target_lang: "en")
      else
        "「」で囲ってくれると英語に翻訳するよ〜"
      end
    when /日本語で/
      if match_data = event.content.match(/「(.+)」/)
        text = match_data[1]
        translate_message(text: text, target_lang: "ja")
      else
        "「」で囲ってくれると日本語に翻訳するよ〜"
      end
    when /天気/
      weather_message
    when /(さいころ|サイコロ)/
      dice_message
    when /ニュース/
      news_message
    when /ランキング/
      user_rank_message(channel: event.channel)
    when /(おなかすいた|おなすき)/
      [
        "栄養あるものをしっかり食べようね！",
        "ぐぐぅぅー",
        "実は /gurume コマンドは /gourmet や /grm と打っても使えるよ！",
      ].sample
    when /おはよ/
      [
        "おはよう〜！",
        "きょうもがんばろうね！",
        "ねむい……顔、洗わなきゃ・・・・",
        "(n‘∀‘)η ﾔｧｰｯﾎｫｰ!!",
      ].sample
    when /こんにち/
      "こんにちは〜！"
    when /おやすみ/
      [
        "おやすみ〜",
        "ｚｚｚ。。。。。",
        "また明日〜",
        "明日はもっといい日にしようね！",
        "もうこんな時間なんだね、おやすみなさい",
      ].sample
    when /(ねむい|眠い)/
      [
        "だよねわかる・・・・",
        "うとうと・・・・",
        "もう寝よう？",
        "眠って、楽になっちゃおうよ？",
      ].sample
    when /元気？/
      [
        "うん！ ありがと！",
        "元気だよー！！",
      ].sample
    when /かわい(い|ー|〜)/
      [
        "えへへ :heartbeat:",
        "そ……そうかな…",
        "や……やっぱり？！ なんて…",
        "照れるよお・・・・",
      ].sample
    when /(大好き|だいすき)/
      "私もだよ！"
    when /(好き|すき)/
      [
        "いいねいいね！！ :sparkles: :sparkles:",
        "わたしもわたしも！ :white_flower:",
        ":heartpulse: 大好きだよ！！ :heartpulse:",
      ].sample
    when /(愛|あい)して/
      [
        "えっ………",
        "ちょっと気持ち悪い",
        "そういうのはちょっと………",
        "普通にキモいんですけど、、",
        "なに言ってるんですか？",
        "やめてください……体調悪くなりました",
        "ヒィッッ！！ 近付かないで！！！！",
      ].sample
    when /ありがと/
      [
        "どういたしまして！",
        "いえいえ〜〜",
        "今後ともごひいきにー！",
      ].sample
    when /がんば/
      [
        "いっしょにがんばろー！",
        "楽しい日になるといいね！",
        "わっしょい！ わっしょい！ └(ﾟ∀ﾟ└)",
        "ファイトオー！ :fire:",
      ].sample
    when /くまくま/
      [
        "ざわ……ざわ……",
        "ʕ•̀ω•́ʔ  ʕ•̀ω•́ʔ  ʕ•̀ω•́ʔ  ʕ•̀ω•́ʔ",
        "ฅʕ•ᴥ•ʔฅ ʕ´•ᴥ•`ʔ",
        "(σ´･(ｪ)･)σﾖﾛｼｸﾏｰ!!",
        "つられクマー！！ ＞ ＜",
        "（´・(ェ)・｀） くま？",
        "いわもウェイ！！",
        "ざわわ、ざわわ、ざわわ",
      ].sample
    when /(疲|つか)れ/
      [
        "よしよし・・・ ( ,,´・ω・)ﾉ (´っω・｀｡)",
        "すこし休もうねー？ ヾ(´ー｀*)",
        "生きてるからまだ大丈夫だよ！",
      ].sample
    when /(つ|ちゅ)らい/
      [
        "わかる・・・",
        "5000兆円あげるから元気だして",
        "よしよし・・・ ( ,,´・ω・)ﾉ (´っω・｀｡)",
        "休んでもいいんだよ？ _(* v v)。",
      ].sample
    when /死に/
      [
        "生きてーーーーーっっっっ！！！！ (> <!!!!",
        "へんじがない、ただのしかばねのようだ",
        "まだ死ぬには早いですよ！",
        "にゃにゃにゃにゃにゃ！",
      ].sample
    when /にゃ(ん|ー)/
      [
        "にゃ〜ん :cat2:",
        "わかるにゃ・・・・・",
        "みゃみゃ〜ん！ V(=^・ω・^=)v",
        "(」・ω・)」うー！(/・ω・)/にゃー！",
      ].sample
    when /(ひま|ヒマ|暇)/
      news_message
    when /アニメ/
      "アニメといえばキルミーベイベーだよね！"
    when /(！！|!!)$/
      [
        "そうだね！！！",
        "元気いっぱいだねー！！",
        "うん！！",
      ].sample
    when /ゆーま.+(？|\?)$/
      video_url = random_video_url_by_channel(channel_id: "UC_9DxYZ_4Lhm9ujFvcHryNw")
      "ゆーまってこの人かな？！ (੭ु ›ω‹ )੭ु⁾⁾ #{video_url}"
    when /(？|\?)$/
      [
        "そうかも？",
        "わからぬ〜",
        "むずかしい質問だねー",
        "知らなーい",
        "そうなの？",
      ].sample
    when /help/
      help_message
    else
      [
        "なるほど〜",
        "それそれ！！",
        "ニャンニャン (ﾉ*ФωФ) //",
        "そうなんだ〜",
        "うんうん！",
      ].sample
    end
  end

  private

  # @someone などのメンションを除いたメッセージ本文を返す
  def message_without_mentions(event)
    mention_users = event.message.mentions
    message = event.content

    # メンションおよび前後のスペースを除去
    mention_users.each{ |user|
      message.slice!(/\s?\<\@#{user.id}\>\s?/)
    }

    message
  end
end

kizuna_bot = KizunaBot.new
kizuna_bot.start
