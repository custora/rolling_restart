Rolling Restart
=========

A Chef resource for mutual exclusion of blocks of recipe code. Useful for
cross-cluster rolling restarts.

    rolling_restart 'rolling_apache_restarts'
      recipe do
        execute 'service apache2 restart'
      end
      action :nothing
    end
