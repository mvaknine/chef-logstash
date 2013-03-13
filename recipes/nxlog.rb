# Yet another very lightweight shipper
#

include_recipe "build-essential"

pkgs = value_for_platform(
    ["redhat","centos","fedora","scientific"] =>
        {"default" => %w{ TODO }},
    [ "debian", "ubuntu" ] =>
        {"default" => %w{ libpcre3-dev libapr1-dev libcurl4-openssl-dev libexpat1-dev }},
    "default" => %w{ libpcre3-dev libapr1-dev libcurl4-openssl-dev libexpat1-dev }
  )

pkgs.each do |pkg|
  package pkg do
    action :install
  end
end

user node['logstash']['user'] do
  system true
end

group node['logstash']['group'] do
  members [ node['logstash']['user'] ]
end

nxlog_version = node['logstash']['nxlog']['version']

remote_file "#{Chef::Config[:file_cache_path]}/nxlog-ce-#{nxlog_version}.tar.gz" do
  source "#{node['logstash']['nxlog']['url']}/nxlog-ce-#{nxlog_version}.tar.gz"
  checksum node['logstash']['nxlog']['checksum']
  action :create_if_missing
end

directory "/usr/local/var/spool/nxlog/" do
  recursive true;
end

bash "compile-nxlog" do
  cwd Chef::Config[:file_cache_path]
  code <<-EOH
    tar zxvf nxlog-ce-#{nxlog_version}.tar.gz
    cd nxlog-ce-#{nxlog_version}
    ./configure
    make && make install
  EOH
  creates "/usr/local/bin/nxlog"
end

logstash_server_results = search(:node, "roles:#{node['logstash']['beaver']['server_role']}")

if logstash_server_results.empty? then
  logstash_server_ip = "127.0.0.1"
else
  logstash_server_ip = logstash_server_results[0]['ipaddress']
end

template "/usr/local/etc/nxlog.conf" do
  variables(
    :tcphost =>  logstash_server_ip,
    :tcpport =>  "5959"
  )
  notifies :restart, "service[nxlog]"
end

runit_service "nxlog"

