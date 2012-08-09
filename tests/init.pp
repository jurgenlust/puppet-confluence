include tomcat
include postgres

postgres::user { 'confuser': 
	username => 'confuser',
	password => 'confluence_secret_password',
}

postgres::db { 'confdb':
	name => 'confdb',
	owner => 'confuser'
}

class { "confluence": 
	user => "confluence", #the system user that will own the Confluence Tomcat instance
	database_name => "confdb",
	database_driver => "org.postgresql.Driver",
	database_driver_jar => "postgresql-9.1-902.jdbc4.jar",
	database_driver_source => "puppet:///modules/confluence/db/postgresql-9.1-902.jdbc4.jar",
	database_url => "jdbc:postgresql://localhost/confdb",
	database_user => "confuser",
	database_pass => "confluence_secret_password",
	number => 1, # the Tomcat http port will be 8180
	version => "4.2.5", # the Confluence version
	memory => "1024m",
	contextroot => "/",
	webapp_base => "/opt", # Confluence will be installed in /opt/confluence
	require => [Postgres::Db['confdb'],Class["tomcat"]],
}
