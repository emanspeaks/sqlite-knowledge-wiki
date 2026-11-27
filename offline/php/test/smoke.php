<?php
// Each line of output is one check; test/smoke.expected holds the right answers.
error_reporting(E_ALL);
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
echo 'mbstring ', mb_strlen('Ünïcödé'), ' ', mb_strtoupper('straße'), ' ', mb_substr('日本語テキスト', 2, 3), ' ', bin2hex(mb_convert_encoding('é', 'ISO-8859-1', 'UTF-8')), "\n";
echo 'tokenizer ', count(token_get_all('<?php echo 1 + 2;')), ' ', token_name(T_ECHO), "\n";
echo 'session ', var_export(session_status() === PHP_SESSION_NONE, true), ' ', var_export(strlen(session_create_id()) >= 22, true), "\n";
echo 'pdo ', implode(',', PDO::getAvailableDrivers()), "|\n";

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
