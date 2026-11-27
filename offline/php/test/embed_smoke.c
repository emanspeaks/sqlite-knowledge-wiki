/* Starts the embedded interpreter and runs the PHP script named on the
 * command line. The script's output is the test result. */
#include <sapi/embed/php_embed.h>

int main(int argc, char **argv)
{
	if (argc < 2) {
		fprintf(stderr, "usage: php-embed-smoke SCRIPT.php\n");
		return 2;
	}
	int status = 0;
	PHP_EMBED_START_BLOCK(argc, argv)
	zend_file_handle file;
	zend_stream_init_filename(&file, argv[1]);
	if (!php_execute_script(&file)) status = 1;
	zend_destroy_file_handle(&file);
	status = status ? status : EG(exit_status);
	PHP_EMBED_END_BLOCK()
	return status;
}
