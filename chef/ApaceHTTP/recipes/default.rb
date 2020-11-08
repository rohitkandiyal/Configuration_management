#
# Cookbook Name:: ApaceHTTP
# Recipe:: default
#
# 
#
# 
#

#Installing Apache HTTP server by compiling the source code




execute "create_mwgroup" do
  command "groupadd -g 505 mw_grp"
  action :run
  not_if 'grep mw_grp /etc/group'
end

user "mw_admin" do
  comment 'Middleware Admin User'
  uid '505'
  gid 'mw_grp'
  home '/home/mw_admin'
  shell '/bin/bash'
  password 'Symantec@123'
end

%w[ /opt/Apache /opt/Apache/Apache_HTTP /home/mw_admin /opt/Apache/Apache_HTTP/httpd_from_chefserver-2.4.23].each do |path|
  directory path do
    owner 'mw_admin'
    group 'mw_grp'
    mode '0755'
    action :create
  end
end

cookbook_file '/opt/Apache/httpd_from_chefserver-2.4.23.tar.gz' do
  source 'httpd-2.4.23.tar.gz'
  owner 'mw_admin'
  group 'mw_grp'	
  mode '0700'
  action :create
  not_if 'ls -ltr /opt/Apache/Apache_HTTP/httpd_from_chefserver-2.4.23/bin | grep -i http'
end

=begin
--------------The below is used to check the if statement------------
if node['platform'] == 'redhat'
  script 'print' do
  interpreter "bash"
  code <<-EOH
	touch /tmp/platform.txt
	echo "If statement true">/tmp/platform.txt 
	EOH
end
end
=end

script 'install_Apache' do
  interpreter "bash"
  code <<-EOH
	su - mw_admin
        gunzip /opt/Apache/httpd_from_chefserver-2.4.23.tar.gz
        tar -xf /opt/Apache/httpd_from_chefserver-2.4.23.tar -C /opt/Apache/Apache_HTTP
	chown -R mw_admin:mw_grp /opt/Apache/Apache_HTTP/httpd-2.4.23
        cd /opt/Apache/Apache_HTTP/httpd-2.4.23
        ./configure --prefix=/opt/Apache/Apache_HTTP/httpd_from_chefserver-2.4.23 --with-apr=/usr/local/apr --with-pcre=/usr/local/pcre
	make
	make install
	EOH
  not_if 'ls -ltr /opt/Apache/Apache_HTTP/httpd_from_chefserver-2.4.23/bin | grep -i http'
end

script 'change_httpd_conf' do
  interpreter "bash"
  code <<-EOH
        cp /opt/Apache/Apache_HTTP/httpd_from_chefserver-2.4.23/conf/httpd.conf /opt/Apache/Apache_HTTP/httpd_from_chefserver-2.4.23/conf/httpd.conf_backupviachef
	sed -i -e 's/#Include conf\/extra\/httpd-vhosts.conf/Include conf\/extra\/httpd-vhosts.conf/g' /opt/Apache/Apache_HTTP/httpd_from_chefserver-2.4.23/conf/httpd.conf
	sed -i -e 's/Listen 80/Listen #{node['ipaddress']}:80/g' /opt/Apache/Apache_HTTP/httpd_from_chefserver-2.4.23/conf/httpd.conf
	sed -i -e 's/User daemon/User mw_admin/g' /opt/Apache/Apache_HTTP/httpd_from_chefserver-2.4.23/conf/httpd.conf
	sed -i -e 's/Group daemon/Group mw_grp/g' /opt/Apache/Apache_HTTP/httpd_from_chefserver-2.4.23/conf/httpd.conf
	sed -i -e 's/#ServerName www.example.com:80/ServerName #{node['ipaddress']}:80/g' /opt/Apache/Apache_HTTP/httpd_from_chefserver-2.4.23/conf/httpd.conf
        EOH
  not_if 'ls -ltr /opt/Apache/Apache_HTTP/httpd_from_chefserver-2.4.23/conf | grep -i httpd.conf_backupviachef'
end



#
#Configuring virtual host using conf/extra/httpd-vhosts.conf
#


execute "backup_file" do
  command "cp /opt/Apache/Apache_HTTP/httpd_from_chefserver-2.4.23/conf/extra/httpd-vhosts.conf /opt/Apache/Apache_HTTP/httpd_from_chefserver-2.4.23/conf/extra/httpd-vhosts_original.conf"
  action :run
  not_if 'ls -ltr /opt/Apache/Apache_HTTP/httpd_from_chefserver-2.4.23/conf/extra | grep httpd-vhosts_original.conf'
end


node["ApaceHTTP"]["sites"].each do |sitename, data|

	document_root = "/opt/Apache/Apache_HTTP/httpd_from_chefserver-2.4.23/htdocs/#{sitename}"
	
	directory document_root do
		owner 'mw_admin'
		group 'mw_grp'
		mode '0755'
		action :create
	end
	
	template "/opt/Apache/Apache_HTTP/httpd_from_chefserver-2.4.23/conf/extra/#{sitename}.conf" do
		source "virtualhosts.erb"
		mode "0644"
    		variables(
      			:document_root => document_root,
      			:port => data["port"],
      			:serveradmin => data["serveradmin"],
      			:servername => data["servername"]
    		)
	end
	
	template "/opt/Apache/Apache_HTTP/httpd_from_chefserver-2.4.23/htdocs/#{sitename}/index.html" do
		source "index.erb"
		mode "0644"				
		variables(
			:sitename => sitename
		)
	end	

  	directory "/opt/Apache/Apache_HTTP/httpd_from_chefserver-2.4.23/htdocs/#{sitename}/logs" do
		action :create
		owner 'mw_admin'
		group 'mw_grp'
		recursive true
		mode '0755'
	end

end

execute "vhost_file" do
	command "cat /opt/Apache/Apache_HTTP/httpd_from_chefserver-2.4.23/conf/extra/python_program.com.conf /opt/Apache/Apache_HTTP/httpd_from_chefserver-2.4.23/conf/extra/chef_http.com.conf > /opt/Apache/Apache_HTTP/httpd_from_chefserver-2.4.23/conf/extra/httpd-vhosts.conf"
	subscribes :run, 'template[/opt/Apache/Apache_HTTP/httpd_from_chefserver-2.4.23/conf/extra/#{sitename}.conf]', :immediately
end


#make service

script 'make_service' do
  interpreter "bash"
  code <<-EOH
echo '

# chkconfig: - 85 16
case "$1" in
  start)
        /opt/Apache/Apache_HTTP/httpd_from_chefserver-2.4.23/bin/apachectl start
        ;;
  stop)
        /opt/Apache/Apache_HTTP/httpd_from_chefserver-2.4.23/bin/apachectl stop
        ;;
  restart)
	/opt/Apache/Apache_HTTP/httpd_from_chefserver-2.4.23/bin/apachectl restart
	;;
esac

'>/etc/init.d/apache_custom
chmod 755 /etc/init.d/apache_custom

EOH
  not_if 'test -f /etc/init.d/apache_custom'
end

service "apache_custom" do
  action [ :enable, :restart ]
end
