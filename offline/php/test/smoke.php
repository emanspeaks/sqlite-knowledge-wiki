<?php
// Each line of output is one check; test/smoke.expected holds the right answers.
error_reporting(E_ALL & ~E_DEPRECATED);
ini_set('display_errors', '1');

echo 'version ', PHP_VERSION, ' ', PHP_OS_FAMILY, ' ', PHP_SAPI, ' ', PHP_INT_SIZE * 8, "-bit\n";
echo 'json ', json_encode(['a' => 1, 'b' => [true, null, 1.5]]), "\n";
echo 'pcre ', preg_replace('/b+/', 'X', 'abbbc'), ' ', preg_match('/^\p{Lu}\w+$/u', 'Ünïcode'), "\n";
echo 'hash ', substr(hash('sha3-256', 'x'), 0, 8), ' ', hash('crc32b', 'x'), ' ', substr(hash('xxh3', 'x'), 0, 8), "\n";
echo 'date ', gmdate('Y-m-d\TH:i:s', 86400 * 365), ' ', (new DateTimeImmutable('2026-11-27', new DateTimeZone('UTC')))->modify('+1 month')->format('Y-m-d'), "\n";
echo 'spl ', implode(',', iterator_to_array(new ArrayIterator([3, 1, 2]))), ' ', count(new SplObjectStorage()), "\n";
echo 'random ', strlen(random_bytes(16)), ' ', (new Random\Randomizer(new Random\Engine\Mt19937(42)))->getInt(1, 100), "\n";
echo 'serialize ', serialize(['k' => 1.0]), "\n";
echo 'sprintf ', sprintf('%05.1f|%x|%s', 3.14159, 255, str_pad('é', 4, '-')), "\n";

$loaded = array_map('strtolower', get_loaded_extensions());
sort($loaded);
echo 'extensions ', implode(',', $loaded), "\n";
echo 'bcmath ', bcadd('12345678901234567890', '98765432109876543210'), ' ', bcdiv('1', '3', 10), "\n";
echo 'calendar ', cal_days_in_month(CAL_GREGORIAN, 2, 2028), ' ', jdtogregorian(gregoriantojd(11, 27, 2026)), "\n";
echo 'ctype ', var_export(ctype_digit('12345'), true), ' ', var_export(ctype_alpha('ab1'), true), "\n";
echo 'fileinfo ', (new finfo(FILEINFO_MIME_TYPE))->buffer("\x89PNG\r\n\x1a\n\0\0\0\rIHDR"), ' ', (new finfo(FILEINFO_MIME_TYPE))->buffer('<?xml version="1.0"?><svg xmlns="http://www.w3.org/2000/svg"/>'), "\n";
echo 'filter ', var_export(filter_var('a@example.org', FILTER_VALIDATE_EMAIL), true), ' ', var_export(filter_var('12x', FILTER_VALIDATE_INT), true), "\n";
echo 'mbregex ', var_export(mb_ereg('^(\\p{Lu})(\\w+)$', 'Ünïcode', $m), true), ' ', $m[1] ?? '?', ' ', mb_ereg_replace('[äöü]', '_', 'größer als Bär'), ' ', implode('|', mb_split('\\s+', 'a  b c')), "\n";
echo 'mbstring ', mb_strlen('Ünïcödé'), ' ', mb_strtoupper('straße'), ' ', mb_substr('日本語テキスト', 2, 3), ' ', bin2hex(mb_convert_encoding('é', 'ISO-8859-1', 'UTF-8')), "\n";
echo 'tokenizer ', count(token_get_all('<?php echo 1 + 2;')), ' ', token_name(T_ECHO), "\n";
echo 'session ', var_export(session_status() === PHP_SESSION_NONE, true), ' ', var_export(strlen(session_create_id()) >= 22, true), "\n";
echo 'pdo ', implode(',', PDO::getAvailableDrivers()), "\n";
echo 'zlib ', strlen(gzcompress(str_repeat('wiki ', 1000))) < 100 ? 'small' : 'big', ' ', gzuncompress(gzcompress('round trip')), ' ', bin2hex(substr(gzencode('x'), 0, 2)), "\n";

// SQLite the way MediaWiki uses it: PDO, a full-text table, and a database
// file that is opened read-only.
$dir = sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'php-smoke-' . bin2hex(random_bytes(4));
mkdir($dir);
$db = new PDO("sqlite:$dir/test.sqlite");
$db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$db->exec('CREATE TABLE page (id INTEGER PRIMARY KEY, title TEXT)');
$db->exec('CREATE VIRTUAL TABLE searchindex USING FTS3(si_title, si_text)');
$insert = $db->prepare('INSERT INTO page (title) VALUES (?)');
foreach (['Falcon 9', 'Electron'] as $t) { $insert->execute([$t]); }
$db->exec("INSERT INTO searchindex VALUES ('falcon 9', 'rocket has mass 549054'), ('electron', 'small rocket')");
$hits = $db->query("SELECT si_title FROM searchindex WHERE searchindex MATCH 'rocket' ORDER BY si_title")->fetchAll(PDO::FETCH_COLUMN);
$meta = $db->query('SELECT title FROM page')->getColumnMeta(0);
echo 'pdo_sqlite ', $db->query('SELECT count(*) FROM page')->fetchColumn(), ' ', implode('+', $hits), ' ', $meta['table'] ?? '?', ' ', $db->query("SELECT json_extract('{\"a\":[1,2]}', '$.a[1]')")->fetchColumn(), "\n";
// Windows will not delete a file that is still open, so let go of the
// statement as well as the connection.
$insert = null;
$db = null;
$before = hash_file('sha256', "$dir/test.sqlite");
$ro = new SQLite3("$dir/test.sqlite", SQLITE3_OPEN_READONLY);
$ro->enableExceptions(true);
try { $ro->exec("INSERT INTO page (title) VALUES ('x')"); $w = 'written'; } catch (Exception $e) { $w = 'refused'; }
echo 'sqlite3 ', $ro->querySingle('SELECT title FROM page WHERE id = 2'), ' ', $w, ' ', var_export($before === hash_file('sha256', "$dir/test.sqlite"), true), ' ', version_compare(SQLite3::version()['versionString'], '3.54.0', '>=') ? 'current' : 'old', "\n";
$ro->close();
unlink("$dir/test.sqlite");
rmdir($dir);

$doc = new DOMDocument();
$doc->loadXML('<wiki><page id="1">Falcon 9</page><page id="2">Electron</page></wiki>');
$xp = new DOMXPath($doc);
$html = new DOMDocument();
@$html->loadHTML('<html><body><p class="x">Héllo <b>world</b></p></body></html>');
echo 'dom ', $xp->evaluate('string(//page[@id="2"])'), ' ', $doc->getElementsByTagName('page')->length, ' ', $html->getElementsByTagName('b')->item(0)->textContent, ' ', LIBXML_DOTTED_VERSION, "\n";
$sx = simplexml_load_string('<a><b c="d">e</b><b>f</b></a>');
echo 'simplexml ', (string)$sx->b[0]['c'], ' ', (string)$sx->b[1], ' ', count($sx->b), "\n";
$parser = xml_parser_create('UTF-8');
$names = [];
xml_set_element_handler($parser, function ($p, $name) use (&$names) { $names[] = $name; }, function () {});
xml_parse($parser, '<r><x/><y>t</y></r>', true);
echo 'xml ', implode(',', $names), ' ', utf8_decode('é') === "\xe9" ? 'latin1' : 'no', "\n";
$reader = new XMLReader();
$reader->XML('<r><i n="1"/><i n="2"/></r>');
$seen = '';
while ($reader->read()) { if ($reader->nodeType === XMLReader::ELEMENT && $reader->name === 'i') { $seen .= $reader->getAttribute('n'); } }
$writer = new XMLWriter();
$writer->openMemory();
$writer->startElement('out'); $writer->writeAttribute('k', 'v&w'); $writer->text('<t>'); $writer->endElement();
echo 'xmlreader ', $seen, ' xmlwriter ', $writer->outputMemory(), "\n";

echo 'iconv ', bin2hex(iconv('UTF-8', 'ISO-8859-1', 'é')), ' ', iconv('UTF-8', 'ASCII//TRANSLIT', 'naïve café'), ' ', iconv_strlen('日本語', 'UTF-8'), ' ', bin2hex(iconv('UTF-8', 'UTF-16BE', 'A')), "\n";

// GD the way MediaWiki makes thumbnails: decode, scale, encode.
$im = imagecreatetruecolor(64, 48);
imagefilledrectangle($im, 0, 0, 63, 47, imagecolorallocate($im, 200, 30, 30));
ob_start(); imagepng($im); $png = ob_get_clean();
ob_start(); imagejpeg($im, null, 90); $jpg = ob_get_clean();
$thumb = imagescale(imagecreatefromstring($jpg), 16, 12);
$px = imagecolorsforindex($thumb, imagecolorat($thumb, 8, 6));
$info = getimagesizefromstring($png);
echo 'gd ', bin2hex(substr($png, 1, 3)), ' ', bin2hex(substr($jpg, 0, 2)), ' ', imagesx($thumb), 'x', imagesy($thumb), ' ', $px['red'] > 180 && $px['green'] < 60 ? 'red' : 'wrong', ' ', $info[0], 'x', $info[1], ' ', $info['mime'], "\n";

// intl: ICU and its built-in data.
$words = ['zebra', 'Äpfel', 'apple', 'Zürich'];
(new Collator('de_DE'))->sort($words);
echo 'intl ', implode(',', $words), ' ', (new NumberFormatter('en_US', NumberFormatter::DECIMAL))->format(1234567.5), ' ', (new NumberFormatter('de_DE', NumberFormatter::DECIMAL))->format(1234567.5), ' ', strlen(Normalizer::normalize("e\u{301}", Normalizer::FORM_C)), ' ', Transliterator::create('Any-Latin; Latin-ASCII')->transliterate('Москва'), ' ', idn_to_ascii('bücher.de'), ' ', IntlDateFormatter::formatObject(new DateTime('2026-11-27 12:00:00', new DateTimeZone('UTC')), 'EEEE d MMMM y', 'fr_FR'), ' ', explode('.', INTL_ICU_VERSION)[0], ' ', count(ResourceBundle::getLocales('')) > 500 ? 'locales' : 'few', "\n";

// OPcache: compile a script into the cache and find it there.
$cached = sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'php-smoke-' . bin2hex(random_bytes(4)) . '.php';
file_put_contents($cached, '<?php return 6 * 7;');
touch($cached, time() - 3600);
$status = opcache_get_status(false);
echo 'opcache ', var_export($status['opcache_enabled'] ?? false, true), ' ', var_export(opcache_compile_file($cached), true), ' ', var_export(opcache_is_script_cached($cached), true), ' ', include $cached, ' ', var_export($status['jit']['enabled'] ?? false, true), "\n";
unlink($cached);

// Lua the way Scribunto uses it: load a chunk, call into it, let it call
// back into PHP, and catch a Lua error and a memory limit as exceptions.
$sandbox = new LuaSandbox();
$sandbox->setMemoryLimit(8 * 1024 * 1024);
$sandbox->registerLibrary('php', ['double' => fn ($x) => [$x * 2]]);
$chunk = $sandbox->loadString('local t = {} for i = 1, 5 do t[#t + 1] = php.double(i) end return table.concat(t, ","), string.rep("ab", 3), _VERSION');
$lua = $chunk->call();
try { $sandbox->loadString('error("from lua")')->call(); $err = 'none'; } catch (LuaSandboxRuntimeError $e) { $err = preg_replace('/^.*: /', '', $e->getMessage()); }
try { $sandbox->loadString('local s = "x" while true do s = s .. s end')->call(); $mem = 'none'; } catch (LuaSandboxMemoryError $e) { $mem = 'memory limit'; }
$sandbox->setCPULimit(0.25);
$started = microtime(true);
try { $sandbox->loadString('local n = 0 while true do n = n + 1 end')->call(); $cpu = 'none'; } catch (LuaSandboxTimeoutError $e) { $cpu = 'cpu limit'; }
$took = microtime(true) - $started;
echo 'luasandbox ', implode(' ', $lua), ' | ', $err, ' | ', $mem, ' | ', $cpu, ' ', $took > 0.2 && $took < 3 ? 'in time' : 'took ' . round($took, 2), ' ', $sandbox->getCPUUsage() > 0.2 ? 'usage counted' : 'no usage', "\n";

// Fibers switch stacks through the routines converted from PHP's own
// Microsoft-syntax assembly, so exercise them properly: values passed both
// ways, nesting, many switches, exceptions crossing the boundary, and a
// fiber that is never finished.
$fiber = new Fiber(function (int $start): string {
    $x = Fiber::suspend($start + 1);
    $y = Fiber::suspend($x * 2);
    return "done:$y";
});
$a = $fiber->start(10);
$b = $fiber->resume(21);
$fiber->resume(7);
echo 'fiber basic ', $a, ' ', $b, ' ', $fiber->getReturn(), ' ', var_export($fiber->isTerminated(), true), "\n";

$outer = new Fiber(function (): int {
    $inner = new Fiber(function (): int {
        $sum = 0;
        for ($i = 0; $i < 1000; $i++) {
            $sum += Fiber::suspend($i);
        }
        return $sum;
    });
    $v = $inner->start();
    $total = 0;
    while (!$inner->isTerminated()) {
        $total += $v;
        $v = $inner->resume(Fiber::suspend($v));
    }
    return $total + $inner->getReturn();
});
$v = $outer->start();
$n = 0;
while (!$outer->isTerminated()) {
    $n++;
    $v = $outer->resume(2);
}
echo 'fiber nested ', $n, ' ', $outer->getReturn(), "\n";

$thrower = new Fiber(function (): void {
    try {
        Fiber::suspend('ready');
    } catch (RuntimeException $e) {
        throw new LogicException('rethrown:' . $e->getMessage());
    }
});
$state = $thrower->start();
try {
    $thrower->throw(new RuntimeException('boom'));
} catch (LogicException $e) {
    echo 'fiber exception ', $state, ' ', $e->getMessage(), "\n";
}

$fibers = [];
for ($i = 0; $i < 200; $i++) {
    $f = new Fiber(function () use ($i): int {
        $deep = function (int $d) use (&$deep, $i): int {
            return $d === 0 ? Fiber::suspend($i) : $deep($d - 1) + 1;
        };
        return $deep(50);
    });
    $f->start();
    $fibers[] = $f;
}
$sum = 0;
foreach ($fibers as $i => $f) {
    if ($i % 2 === 0) {
        $f->resume($i);
        $sum += $f->getReturn();
    }
}
unset($fibers); // half of them are destroyed while suspended
gc_collect_cycles();
echo 'fiber many ', $sum, "\n";

function gen() { $x = yield 1; yield $x + 1; }
$g = gen(); $first = $g->current(); $second = $g->send(41);
echo 'generator ', $first, ' ', $second, "\n";
echo "end\n";
