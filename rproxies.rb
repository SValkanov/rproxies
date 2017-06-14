require 'json'
require 'ipaddr'
require 'open-uri'
require 'time'
require 'csv'
require 'optparse'
require 'parallel'

def banner
  "
                                                oo

  88d888b.  88d888b. 88d888b. .d8888b. dP.  .dP dP .d8888b. .d8888b.
  88'  `88  88'  `88 88'  `88 88'  `88  `8bd8'  88 88ooood8 Y8ooooo.
  88        88.  .88 88       88.  .88  .d88b.  88 88.  ...       88
  dP        88Y888P' dP       `88888P' dP'  `dP dP `88888P' `88888P'
            88
            dP                                                       v#{version}"
end

def version
  "1.0.0"
end

def user_agent
  fixed_curl_minor, fixed_curl_revision = curl_minor, curl_revision
  "curl/7.#{fixed_curl_minor}.#{fixed_curl_revision} (x86_64-pc-linux-gnu) libcurl/7.#{fixed_curl_minor}.#{fixed_curl_revision} OpenSSL/0.9.8#{openssl_revision} zlib/1.2.#{zlib_revision}"
end

def referer
  "https://hidester.com/proxylist/"
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
  {"elite" => "high", "anonymous" => "medium", "transparent" => "low"}
end

def proxy_list_url
  "https://hidester.com/proxydata/php/data.php?mykey=csv&gproxy=2"
end

def ifconfig_candidates
  ["https://ifconfig.co/ip", "https://api.ipify.org/?format=text", "https://ifconfig.io/ip", "https://ifconfig.minidump.info/ip", "https://myexternalip.com/raw", "https://wtfismyip.com/text"]
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

def csv
  @csv ||= CSV.new(File.new(handler, "wb"), headers: ['Proxy', 'Latency', 'Country', 'Anonimity'], write_headers: true)
  @csv
end

def is_ip?(ip)
  !!IPAddr.new(ip) rescue false
end

def start_loading_progress
  Thread.new{
    counter = [0]
    while true
      counter[0] += 1
      print ("\r#{rotation_chars[counter[0] % rotation_chars.length]}\r")
      sleep 0.2
    end
  }
end

def retrieve(url, headers={'User-agent' => user_agent, 'Referer' => ''}, proxy=nil)
  begin
    retval =  open(url, proxy: proxy, read_timeout: timeout_option,
      'User-Agent' => headers['User-agent'],
      'Referer' => headers['Referer']).read
  rescue => e
    retval = e
  end
  retval
end

def retrieve_proxies
  puts '[i] retrieving list of proxies...'
  begin
    proxies = JSON.parse(retrieve(proxy_list_url, headers={"User-agent" => user_agent, "Referer" => referer})).shuffle!
  rescue
    puts '[!] something went wrong during the proxy list retrieval/parsing. Please check your network settings and try again'
    abort
  end
end

def initialize_ifconfig
  puts '[i] initial testing...'
  ifconfig_candidates.each do |candidate|
    result = retrieve(candidate)
    if is_ip? result
      @ifconfig_url = candidate
      break
    end
  end
end

def proxy_verification proxy
  begin
    proxy_ip = proxy['IP']
    proxy_country = proxy['country']
    proxy_anonimity = proxy['anonymity']
    proxy_url = "#{proxy['type']}://#{proxy_ip}:#{proxy['PORT']}"
    start = Time.now
    result = retrieve(@ifconfig_url, headers={"User-agent" => user_agent, "Referer" => ''}, proxy=proxy_url)
    if result == proxy_ip
      latency = (Time.now - start)
      puts "#{proxy_url}#{' ' * (32 - proxy_url.length)} # latency: #{latency.round(2)} sec; country: #{proxy_country}; anonimity: #{proxy_anonimity}(#{anonimity_levels[proxy_anonimity.downcase]})\n"
      csv << [proxy_url, latency, proxy_country, anonimity_levels[proxy_anonimity.downcase]] if handler
    end
  rescue
    return
  end
end

def input_options
  @input_options ||= parse_flags
end

def parse_flags
  begin
    options = {}
    OptionParser.new do |opt|
      opt.on('--timeout Time to wait each request to respond (default 10s)') { |o| options[:timeout] = o }
      opt.on('--threads Number of scanning threads (default 10)') { |o| options[:threads] = o }
      opt.on('--dump    Path to write the results in csv (e.g. "/home/output.csv")')  { |o| options[:dump] = o }
    end.parse!
    return options
  rescue
    puts "[!] Use '-h' to see available options\n"
    abort
  end
end

def run
  puts "#{banner}\n\n"
  input_options
  start_loading_progress
  initialize_ifconfig
  proxies = retrieve_proxies
  puts "[i] testing #{proxies.length} proxies (#{threads} threads)...\n\n"
  Parallel.map(proxies, in_threads: threads) { |proxy| proxy_verification proxy }
  csv.rewind if handler; puts "\n[i] finished."
end

trap("SIGINT") { csv.rewind if handler;puts "\n\r[!] Ctrl-C pressed\r"; exit}

run
