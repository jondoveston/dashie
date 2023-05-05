require 'net/http'
require 'json'
require 'yaml'

PROMETHEUS = URI(ENV.fetch('PROMETHEUS', 'http://localhost:9090/api/v1/query'))

def query(q)
  params = { query: q }
  uri = PROMETHEUS.clone
  uri.query = URI.encode_www_form(params)
  res = Net::HTTP.get_response(uri)
  if res.is_a?(Net::HTTPSuccess)
    json = JSON.parse(res.body)
    if json['status'] == 'success'
      results = json.fetch('data', {}).fetch('result', []).map do |result|
        instance = result.fetch('metric', {}).fetch('instance', nil).split('.').first
        value = result.fetch('value', nil)
        [instance, value] if instance && value && value.any?
      end.compact
      return results.to_h if results.any?
    end
  end
  {}
end

def format_cpu(value)
  value.to_f.round
end

def format_mem(value)
  value.to_f.round
end

def format_uptime(value)
  t = value.to_i
  "%02d:%02d:%02d:%02d" % [t/86400, t/3600%24, t/60%60, t%60]
end

def format_load(value)
  value.to_f.round(2)
end

hosts = YAML.load_file('config.yml').keys

SCHEDULER.every '5s', :first_in => '0s' do
  number_of_logical_cores = query(%(count by (instance)(node_cpu_seconds_total{mode="idle"})))
  mem_total = query(%(node_memory_MemTotal_bytes / 1000000000))

  cpu_used = query(%(100 - (avg by(instance)(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)))
  mem_used = query(%((node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / 1000000000))
  load1 = query(%(node_load1))
  load5 = query(%(node_load5))
  load15 = query(%(node_load15))
  uptime = query(%(time()-node_boot_time_seconds))

  root = query(%(100 - (node_filesystem_avail_bytes{mountpoint="/"}/node_filesystem_size_bytes{mountpoint="/"} * 100)))
  pool = query(%(100 - (node_filesystem_avail_bytes{mountpoint="/mnt/pool"}/node_filesystem_size_bytes{mountpoint="/mnt/pool"} * 100)))
  tank = query(%(100 - (node_filesystem_avail_bytes{mountpoint=~"/(mnt|Volumes)/tank"}/node_filesystem_size_bytes{mountpoint=~"/(mnt|Volumes)/tank"} * 100)))
  data = query(%(100 - (node_filesystem_avail_bytes{mountpoint=~"/(mnt|Volumes)/data"}/node_filesystem_size_bytes{mountpoint=~"/(mnt|Volumes)/data"} * 100)))
  home = query(%(100 - (node_filesystem_avail_bytes{mountpoint="/home"}/node_filesystem_size_bytes{mountpoint="/home"} * 100)))

  hosts.each do |host|
    send_event("#{host}_uptime", { current: format_uptime(uptime.fetch(host, []).last) })
    send_event("#{host}_cpu_used", { value: format_cpu(cpu_used.fetch(host, []).last) })
    send_event("#{host}_mem_used", { value: format_mem(mem_used.fetch(host, []).last), min: 0, max: format_mem(mem_total.fetch(host, []).last) })
    send_event("#{host}_load1", { value: format_load(load1.fetch(host, []).last), min: 0, max: number_of_logical_cores.fetch(host, []).last })
    send_event("#{host}_load5", { value: format_load(load5.fetch(host, []).last), min: 0, max: number_of_logical_cores.fetch(host, []).last })
    send_event("#{host}_load15", { value: format_load(load15.fetch(host, []).last), min: 0, max: number_of_logical_cores.fetch(host, []).last })
    send_event("#{host}_root", { value: format_mem(root.fetch(host, []).last) })
    send_event("#{host}_pool", { value: format_mem(pool.fetch(host, []).last) })
    send_event("#{host}_tank", { value: format_mem(tank.fetch(host, []).last) })
    send_event("#{host}_home", { value: format_mem(home.fetch(host, []).last) })
  end
end
