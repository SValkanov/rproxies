require 'json'
require 'ipaddr'
require 'open3'
require 'time'
require 'csv'
require 'optparse'
require 'thread'

def banner
  "
                                                oo

  88d888b.  88d888b. 88d888b. .d8888b. dP.  .dP dP .d8888b. .d8888b.
  88'  `88  88'  `88 88'  `88 88'  `88  `8bd8'  88 88ooood8 Y8ooooo.
  88        88.  .88 88       88.  .88  .d88b.  88 88.  ...       88
  dP        88Y888P' dP       `88888P' dP'  `dP dP `88888P' `88888P'
            88
            dP                                                      v#{version}"
end

def version
  '2.3.1'
end

def user_agent
  fixed_curl_minor = curl_minor
  fixed_curl_revision = curl_revision
  "curl/7.#{fixed_curl_minor}.#{fixed_curl_revision} (x86_64-pc-linux-gnu) libcurl/7.#{fixed_curl_minor}.#{fixed_curl_revision} OpenSSL/0.9.8#{openssl_revision} zlib/1.2.#{zlib_revision}"
end

def curl_minor
  random.rand(8..22)
end

def curl_revision
  random.rand(1..9)
end

def openssl_revision
  ('a'..'z').to_a[random.rand(0..25)]
end

def zlib_revision
  random.rand(2..6)
end

def random
  Random.new
end

def anonimity_levels
  { 'high' => "#{green 'elite'}", 'medium' => "#{yellow 'anonymous'}", 'low' => 'transparent' }
end

def proxy_list_url
  'https://raw.githubusercontent.com/stamparm/aux/master/fetch-some-list.txt'
end

def ifconfig_candidates
  ['https://ifconfig.co/ip', 'https://api.ipify.org/?format=text', 'https://ifconfig.io/ip', 'https://myexternalip.com/raw', 'https://wtfismyip.com/text', 'https://icanhazip.com/', 'https://ipv4bot.whatismyipaddress.com/', 'https://ip4.seeip.org']
end

def rotation_chars
  ['/', '-', '\\', '|']
end

def timeout_option
  (input_options[:timeout] || 10).to_i
end

def threads
  (input_options[:threads] || 10).to_i
end

def output
  input_options[:output]
end

def handler
  input_options[:dump]
end

def country_filter
  input_options[:country]
end

def anonymity_filter
  input_options[:anonymity]
end

def type_filter
  input_options[:type]
end

def colorize text, color_code
  "\e[#{color_code}m#{text}\e[0m"
end

def green text
  colorize text, 32
end

def yellow text
  colorize text, 33
end

def csv
  @csv ||= CSV.new(File.new(handler, 'wb'), headers: %w[Proxy Latency Country Anonimity], write_headers: true)
  @csv
end

def ip?(ip)
  !!IPAddr.new(ip)
rescue
  false
end

def curl_requests url, proxy
  {
    true => "curl -m #{timeout_option} -A \"#{user_agent}\" #{url}",
    false => "curl -m #{timeout_option} -A \"#{user_agent}\" --proxy #{proxy} #{url}"
  }
end

def curl_request(url, proxy = nil)
  curl_requests_list = curl_requests url, proxy
  curl_requests_list[proxy.nil?]
end

def start_loading_progress
  Thread.new do
    counter = [0]
    loop do
      counter[0] += 1
      print "\r#{rotation_chars[counter[0] % rotation_chars.length]}\r"
      sleep 0.2
    end
  end
end

def retrieve(url, headers = { 'User-agent' => user_agent }, proxy = nil)
  begin
    stdin, stdout, stderr, wait_thr1 = Open3.popen3(curl_request(url, proxy))
    retval = stdout.read
  rescue => error
    retval = error
  end
  retval
end

def retrieve_proxies
  puts '[i] retrieving list of proxies...'
  begin
    ret = JSON.parse(retrieve(proxy_list_url, { 'User-agent' => user_agent })).shuffle!
  rescue
    puts '[!] something went wrong during the proxy list retrieval/parsing. Please check your network settings and try again'
    abort
  end

  if country_filter
    ret.select! { |proxy| country_filter.include? proxy['country'].downcase }
  end

  if anonymity_filter
    ret.select! { |proxy| anonymity_filter.include? proxy['anonymity'] }
  end

  if type_filter
    ret.select! { |proxy| type_filter.include? proxy['proto'] }
  end
  ret
end

def initialize_ifconfig
  puts '[i] initial testing...'
  ifconfig_candidates.each do |candidate|
    result = retrieve(candidate)
    if ip? result
      @ifconfig_url = candidate
      break
    end
  end
end

def proxy_verification(proxy)
  proxy_url = "#{proxy['proto']}://#{proxy['ip']}:#{proxy['port']}"
  start = Time.now
  anonimity_level = anonimity_levels[proxy['anonymity']]
  result = retrieve(@ifconfig_url, { 'User-agent' => user_agent }, proxy_url)
  if result == proxy['ip']
    latency = (Time.now - start)
    puts "#{proxy_url}#{' ' * (32 - proxy_url.length)} # latency: #{latency.round(2)} sec; country: #{proxy['country']}; anonimity: #{proxy['anonymity']}(#{anonimity_level})\n"
    csv << [proxy_url, latency, proxy['country'], anonimity_level.gsub(/\e\[(\d+)m/, '')] if handler
  end
rescue
  return
end

def input_options
  @input_options ||= parse_flags
end

def parse_flags
  options = {}
  OptionParser.new do |opt|
    opt.on('--timeout   Time to wait each request to respond (default 10s)') { |o| options[:timeout] = o }
    opt.on('--threads   Number of scanning threads (default 10)') { |o| options[:threads] = o }
    opt.on('--dump      Path to write the results in csv (e.g. "/home/output.csv")') { |o| options[:dump] = o }
    opt.on('--anonymity Filtering by anonymity (e.g. "medium|high")') { |o| options[:anonymity] = o.split('|').map(&:downcase) }
    opt.on('--country   Filtering by country (e.g. "china|brazil")') { |o| options[:country] = o.split('|').map(&:downcase) }
    opt.on('--type      Filtering by type (e.g. "http|https")') { |o| options[:type] = o.split('|').map(&:downcase) }
  end.parse!
  return options
rescue
  puts "[!] Use '-h' to see available options\n"
  abort
end

def parallel_run proxies
  queue = Queue.new
  proxies.each{|proxy| queue << proxy }

  running_threads = []
  threads.times do
      running_threads << Thread.new do
        while (proxy = queue.pop(true) rescue nil)
          proxy_verification proxy
        end
      end
  end

  running_threads.each {|t| t.join }
end

def run
  puts "#{banner}\n\n"
  input_options
  start_loading_progress
  initialize_ifconfig
  proxies = retrieve_proxies
  puts "[i] testing #{proxies.length} proxies (#{threads} threads)...\n\n"
  parallel_run proxies
  csv.rewind if handler; puts "\n[i] finished."
end

trap('SIGINT') { csv.rewind if handler; puts "\n\r[!] Ctrl-C pressed\r"; exit }

run
