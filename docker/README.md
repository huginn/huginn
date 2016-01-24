Huginn Docker images
====================

Huginn is packaged in two docker images.

#### `cantino/huginn` multiple process image

This image runs all processes needed by Huginn in one container, when not database is linked it will also start MySQL internally. It is great to try huginn without having to set up anything, however maintenance and backups can be difficult.

#### `cantino/huginn-single-process` multiple container image

This image runs just one process per container and thus needs at least two container to be started, one for the Huginn application server and one for the threaded background worker. It is also possible to every background worker in a separate container to improve the performance. See [the PostgreSQL docker-compose configuration](single-process/postgres.yml) for an example.
