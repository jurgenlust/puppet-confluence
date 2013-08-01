# Class: confluence
#
# This module manages confluence
#
# Parameters:
#
# Actions:
#
# Requires:
#
# Sample Usage:
#
# [Remember: No empty lines between comments and class definition]
class confluence (
	$user = "confluence",	
	$database_name = "confluence",
	$database_driver = "org.postgresql.Driver",
	$database_driver_jar = "postgresql-9.1-902.jdbc4.jar",
	$database_driver_source = "puppet:///modules/confluence/db/postgresql-9.1-902.jdbc4.jar",
	$database_url = "jdbc:postgresql://localhost/confluence",
	$database_user = "confluence",
	$database_pass = "confluence",
	$memory = "512m",
	$number = 1,
	$version = "5.1.4",
	$contextroot = "confluence",
	$webapp_base = "/srv"
){
	
# configuration
	$confluence_build = "confluence-${version}" 
	$tarball = "atlassian-${confluence_build}-war.tar.gz"
	$download_dir = "/tmp"
	$downloaded_tarball = "${download_dir}/${tarball}"
	$download_url = "http://www.atlassian.com/software/confluence/downloads/binary/${tarball}"
	$build_parent_dir = "${webapp_base}/${user}/build"
	$build_dir = "${build_parent_dir}/${version}"
	$confluence_dir = "${webapp_base}/${user}"
	$confluence_home = "${webapp_base}/${user}/confluence-home"
	
	$webapp_context = $contextroot ? {
	  '/' => '',	
      '' => '',
      default  => "/${contextroot}"
    }
    
    $webapp_war = $contextroot ? {
    	'' => "ROOT.war",
    	'/' => "ROOT.war",
    	default => "${contextroot}.war"	
    }
	
# download the WAR-EAR distribution of Confluence
	exec { "download-confluence":
		command => "/usr/bin/wget -O ${downloaded_tarball} ${download_url}",
		require => Tomcat::Webapp::User[$user],
		creates => $downloaded_tarball,
		timeout => 1200,	
	}
	
	file { $downloaded_tarball :
		require => Exec["download-confluence"],
		ensure => file,
	}
	
# prepare the Confluence build
	file { $build_parent_dir:
		ensure => directory,
		owner => $user,
		group => $user,
		require => Tomcat::Webapp::User[$user],
	}
	
	exec { "extract-confluence":
		command => "/bin/tar -xvzf ${tarball} && mv ${confluence_build} ${build_dir}",
		cwd => $download_dir,
		user => $user,
		creates => "${build_dir}/build.sh",
		timeout => 1200,
		require => [File[$downloaded_tarball],File[$build_parent_dir]],	
		notify => [
			Exec['clean-confluence']	
		],	
	}

	file { $build_dir:
		ensure => directory,
		owner => $user,
		group => $user,
		require => Exec["extract-confluence"],
	}
	
	
	file { $confluence_home:
		ensure => directory,
		mode => 0755,
		owner => $user,
		group => $user,
		require => Tomcat::Webapp::User[$user],
	}
	
	file { "confluence.properties":
		path => "${build_dir}/confluence/WEB-INF/classes/confluence-init.properties",
		content => template("confluence/confluence-init.properties.erb"),
		require => Exec["extract-confluence"],
	}

# clean the previous Confluence war-file	
	exec { "clean-confluence":
		command => "/bin/rm -rf ${webapp_base}/${user}/tomcat/webapps/*",
		user => $user,
		refreshonly => true,
		notify => Exec["build-confluence"],
		require => [
			Tomcat::Webapp::Tomcat[$user]
		],
	}

# build the Confluence war-file
	
	exec { "build-confluence":
		command => "/bin/sh build.sh && mv ${build_dir}/dist/${confluence_build}.war ${webapp_base}/${user}/tomcat/webapps/${webapp_war}",
		user => $user,
		creates => "${webapp_base}/${user}/tomcat/webapps/${webapp_war}",
		timeout => 0,
		refreshonly => true,
		cwd => $build_dir,
		require => [File["confluence.properties"], Tomcat::Webapp::Tomcat[$user]],
		notify => Tomcat::Webapp::Service[$user]
	}
	
	file { 'confluence-war' :
		path => "${webapp_base}/${user}/tomcat/webapps/${webapp_war}", 
		ensure => file,
		owner => $user,
		group => $user,
		require => Exec["build-confluence"],
	}
	
# the database driver jar
	file { 'confluence-db-driver':
		path => "${confluence_dir}/tomcat/lib/${database_driver_jar}", 
		source => $database_driver_source,
		ensure => file,
		owner => $user,
		group => $user,
		require => Tomcat::Webapp::Tomcat[$user],
	}    
	
# manage the Tomcat instance
	tomcat::webapp { "${user}" :
		username => $user, 
		number => $number,
		webapp_base => $webapp_base,
		java_opts => "-server -Dorg.apache.jasper.runtime.BodyContentImpl.LIMIT_BUFFER=true -Dmail.mime.decodeparameters=true -Xms${memory} -Xmx${memory} -XX:MaxPermSize=256m -Djava.awt.headless=true",
		server_host_config => template("confluence/context.erb"),
		service_require => [File['confluence-war'], File['confluence-db-driver'], File[$confluence_home]],
		require => Class["tomcat"],
	}
	
	
}
