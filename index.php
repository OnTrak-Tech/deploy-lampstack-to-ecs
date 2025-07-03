<?php
$secret_json = getenv('DB_SECRET_JSON');
$secret = json_decode($secret_json, true);

$db_host = $secret['DB_HOST'];
$db_user = $secret['DB_USERNAME'];
$db_pass = $secret['DB_PASSWORD'];
$db_name = $secret['DB_DATABASE'];

try {
    $pdo = new PDO("mysql:host=$db_host;dbname=$db_name", $db_user, $db_pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Create table if not exists
    $pdo->exec("CREATE TABLE IF NOT EXISTS visitors (
        id INT AUTO_INCREMENT PRIMARY KEY,
        ip_address VARCHAR(45),
        user_agent TEXT,
        visit_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        page_url VARCHAR(255)
    )");
    
    // Record visitor
    $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
    $userAgent = $_SERVER['HTTP_USER_AGENT'] ?? 'unknown';
    $pageUrl = $_SERVER['REQUEST_URI'] ?? '/';
    
    $stmt = $pdo->prepare("INSERT INTO visitors (ip_address, user_agent, page_url) VALUES (?, ?, ?)");
    $stmt->execute([$ip, $userAgent, $pageUrl]);
    
    // Get analytics data
    $totalVisits = $pdo->query("SELECT COUNT(*) FROM visitors")->fetchColumn();
    $uniqueVisitors = $pdo->query("SELECT COUNT(DISTINCT ip_address) FROM visitors")->fetchColumn();
    $todayVisits = $pdo->query("SELECT COUNT(*) FROM visitors WHERE DATE(visit_time) = CURDATE()")->fetchColumn();
    
} catch(PDOException $e) {
    $error = "Connection failed: " . $e->getMessage();
}
?>
<!DOCTYPE html>
<html>
<head>
    <title>Visitors Counter Analytics</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; padding: 20px; }
        .container { max-width: 900px; margin: 0 auto; background: rgba(255,255,255,0.95); padding: 40px; border-radius: 20px; box-shadow: 0 20px 40px rgba(0,0,0,0.1); backdrop-filter: blur(10px); }
        h1 { text-align: center; color: #333; margin-bottom: 40px; font-size: 2.5em; font-weight: 300; }
        .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 25px; margin-bottom: 40px; }
        .stat { background: linear-gradient(135deg, #667eea, #764ba2); color: white; padding: 30px; border-radius: 15px; text-align: center; box-shadow: 0 10px 25px rgba(102,126,234,0.3); transition: transform 0.3s ease; }
        .stat:hover { transform: translateY(-5px); }
        .stat h3 { font-size: 3em; font-weight: 700; margin-bottom: 10px; }
        .stat p { font-size: 1.1em; opacity: 0.9; }
        .info-section { background: #f8f9fa; padding: 25px; border-radius: 15px; margin-top: 30px; }
        .info-item { display: flex; justify-content: space-between; margin-bottom: 15px; padding: 10px 0; border-bottom: 1px solid #e9ecef; }
        .info-label { font-weight: 600; color: #495057; }
        .info-value { color: #6c757d; }
        .error { background: linear-gradient(135deg, #ff6b6b, #ee5a52); color: white; padding: 25px; border-radius: 15px; text-align: center; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Analytics Dashboard</h1>
        
        <?php if (isset($error)): ?>
            <div class="error"><?= htmlspecialchars($error) ?></div>
        <?php else: ?>
            <div class="stats-grid">
                <div class="stat">
                    <h3><?= $totalVisits ?></h3>
                    <p>Total Visits</p>
                </div>
                
                <div class="stat">
                    <h3><?= $uniqueVisitors ?></h3>
                    <p>Unique Visitors</p>
                </div>
                
                <div class="stat">
                    <h3><?= $todayVisits ?></h3>
                    <p>Today's Visits</p>
                </div>
            </div>
            
            <div class="info-section">
                <div class="info-item">
                    <span class="info-label">Your IP Address</span>
                    <span class="info-value"><?= htmlspecialchars($ip) ?></span>
                </div>
                <div class="info-item">
                    <span class="info-label">Visit Time</span>
                    <span class="info-value"><?= date('Y-m-d H:i:s') ?></span>
                </div>
            </div>
        <?php endif; ?>
    </div>
</body>
</html>