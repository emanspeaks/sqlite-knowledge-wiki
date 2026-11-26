#include <sapi/embed/php_embed.h>
int main(int argc, char **argv) {
	PHP_EMBED_START_BLOCK(argc, argv)
	zend_eval_string("echo 'PHP ', PHP_VERSION, ' on ', PHP_OS_FAMILY, ' sapi=', PHP_SAPI, ' json=', json_encode([1, 'a' => preg_replace('/b+/', 'X', 'abbbc')]), ' sha=', substr(hash('sha3-256', 'x'), 0, 8), PHP_EOL;", NULL, "embed");
	PHP_EMBED_END_BLOCK()
	return 0;
}
