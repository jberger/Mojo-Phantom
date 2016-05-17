requires 'Mojolicious', '6.0'; # cookie_jar->all returns arrayref
requires 'JavaScript::Value::Escape';
requires 'Role::Tiny';
requires 'Test2', '1.302015'; # Test::Builder + Test2 that works together
requires 'Test2::Suite';
requires 'Test::More';
requires 'Test::Mojo::WithRoles';

configure_requires 'IPC::Cmd';
configure_requires 'Module::Build::Tiny';

author_requires 'App::ModuleBuildTiny';

