<?php
/**
 * Manager Approval Webhook for PrestaShop
 * 处理Manager审批卖家注册后的状态更新
 * 
 * @author Baidaohui Team
 * @version 1.0.0
 */

require_once dirname(__FILE__) . '/../../config/config.inc.php';
require_once dirname(__FILE__) . '/../../init.php';

// 设置响应头
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// 处理OPTIONS请求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// 只允许POST请求
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

// 验证API密钥
$headers = getallheaders();
$authHeader = isset($headers['Authorization']) ? $headers['Authorization'] : '';
$expectedToken = 'Bearer your_webhook_secret_key'; // 应该从配置文件读取

if ($authHeader !== $expectedToken) {
    http_response_code(401);
    echo json_encode(['error' => 'Unauthorized']);
    exit;
}

// 解析请求体
$input = file_get_contents('php://input');
$data = json_decode($input, true);

if (!$data) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid JSON']);
    exit;
}

// 验证必需字段
$requiredFields = ['seller_id', 'email', 'status', 'approved_by', 'approval_time'];
foreach ($requiredFields as $field) {
    if (!isset($data[$field])) {
        http_response_code(400);
        echo json_encode(['error' => "Missing required field: {$field}"]);
        exit;
    }
}

$sellerId = $data['seller_id'];
$email = $data['email'];
$status = $data['status']; // 'approved' or 'rejected'
$approvedBy = $data['approved_by'];
$approvalTime = $data['approval_time'];
$rejectionReason = isset($data['rejection_reason']) ? $data['rejection_reason'] : '';

try {
    // 开始数据库事务
    Db::getInstance()->execute('START TRANSACTION');
    
    if ($status === 'approved') {
        $result = handleApproval($sellerId, $email, $approvedBy, $approvalTime);
    } elseif ($status === 'rejected') {
        $result = handleRejection($sellerId, $email, $approvedBy, $approvalTime, $rejectionReason);
    } else {
        throw new Exception('Invalid status. Must be "approved" or "rejected"');
    }
    
    // 提交事务
    Db::getInstance()->execute('COMMIT');
    
    // 记录日志
    PrestaShopLogger::addLog(
        "Manager approval webhook: Seller {$sellerId} ({$email}) {$status} by {$approvedBy}",
        1,
        null,
        'ManagerApproval'
    );
    
    // 返回成功响应
    http_response_code(200);
    echo json_encode([
        'success' => true,
        'message' => $result['message'],
        'seller_id' => $sellerId,
        'status' => $status,
        'employee_id' => isset($result['employee_id']) ? $result['employee_id'] : null
    ]);
    
} catch (Exception $e) {
    // 回滚事务
    Db::getInstance()->execute('ROLLBACK');
    
    // 记录错误日志
    PrestaShopLogger::addLog(
        "Manager approval webhook error: " . $e->getMessage(),
        3,
        null,
        'ManagerApproval'
    );
    
    http_response_code(500);
    echo json_encode([
        'error' => 'Internal server error',
        'message' => $e->getMessage()
    ]);
}

/**
 * 处理卖家审批通过
 */
function handleApproval($sellerId, $email, $approvedBy, $approvalTime)
{
    // 检查员工是否已存在
    $existingEmployee = getEmployeeByEmail($email);
    
    if ($existingEmployee) {
        // 更新现有员工状态
        $employeeId = $existingEmployee['id_employee'];
        updateEmployeeStatus($employeeId, true);
        
        // 分配卖家权限
        assignSellerPermissions($employeeId);
        
        $message = "Existing employee activated and granted seller permissions";
    } else {
        // 创建新员工账户
        $employeeId = createSellerEmployee($sellerId, $email);
        
        // 分配卖家权限
        assignSellerPermissions($employeeId);
        
        $message = "New seller employee created and activated";
    }
    
    // 更新审批记录
    updateApprovalRecord($sellerId, 'approved', $approvedBy, $approvalTime);
    
    // 发送欢迎邮件
    sendWelcomeEmail($email, $sellerId);
    
    return [
        'message' => $message,
        'employee_id' => $employeeId
    ];
}

/**
 * 处理卖家审批拒绝
 */
function handleRejection($sellerId, $email, $approvedBy, $approvalTime, $rejectionReason)
{
    // 检查员工是否存在
    $existingEmployee = getEmployeeByEmail($email);
    
    if ($existingEmployee) {
        // 禁用员工账户
        $employeeId = $existingEmployee['id_employee'];
        updateEmployeeStatus($employeeId, false);
        
        // 移除卖家权限
        removeSellerPermissions($employeeId);
    }
    
    // 更新审批记录
    updateApprovalRecord($sellerId, 'rejected', $approvedBy, $approvalTime, $rejectionReason);
    
    // 发送拒绝邮件
    sendRejectionEmail($email, $rejectionReason);
    
    return [
        'message' => "Seller application rejected and employee deactivated"
    ];
}

/**
 * 根据邮箱获取员工信息
 */
function getEmployeeByEmail($email)
{
    $sql = 'SELECT * FROM `' . _DB_PREFIX_ . 'employee` WHERE `email` = "' . pSQL($email) . '"';
    return Db::getInstance()->getRow($sql);
}

/**
 * 创建卖家员工账户
 */
function createSellerEmployee($sellerId, $email)
{
    // 生成随机密码
    $password = Tools::generatePassword(12);
    $hashedPassword = password_hash($password, PASSWORD_DEFAULT);
    
    // 获取默认语言和商店
    $defaultLang = (int)Configuration::get('PS_LANG_DEFAULT');
    $defaultShop = (int)Configuration::get('PS_SHOP_DEFAULT');
    
    // 插入员工记录
    $sql = 'INSERT INTO `' . _DB_PREFIX_ . 'employee` (
        `lastname`, `firstname`, `email`, `passwd`, `last_passwd_gen`,
        `stats_date_from`, `stats_date_to`, `stats_compare_from`, `stats_compare_to`,
        `stats_compare_option`, `preselect_date_range`, `bo_color`, `bo_theme`,
        `bo_css`, `default_tab`, `bo_width`, `bo_menu`, `active`, `optin`, `id_last_order`,
        `id_last_customer_message`, `id_last_customer`, `last_connection_date`,
        `id_lang`, `id_profile`
    ) VALUES (
        "Seller", "' . pSQL($sellerId) . '", "' . pSQL($email) . '", "' . pSQL($hashedPassword) . '", "' . date('Y-m-d H:i:s') . '",
        "' . date('Y-m-d') . '", "' . date('Y-m-d') . '", "' . date('Y-m-d') . '", "' . date('Y-m-d') . '",
        1, "", "", "default", "theme.css", 1, 0, 1, 1, 1, 0, 0, 0, NOW(), ' . $defaultLang . ', ' . getSellerProfileId() . '
    )';
    
    if (!Db::getInstance()->execute($sql)) {
        throw new Exception('Failed to create employee record');
    }
    
    $employeeId = Db::getInstance()->Insert_ID();
    
    // 关联到默认商店
    $sql = 'INSERT INTO `' . _DB_PREFIX_ . 'employee_shop` (`id_employee`, `id_shop`) 
            VALUES (' . (int)$employeeId . ', ' . $defaultShop . ')';
    Db::getInstance()->execute($sql);
    
    // 存储临时密码（用于首次登录）
    storeTempPassword($employeeId, $password);
    
    return $employeeId;
}

/**
 * 更新员工状态
 */
function updateEmployeeStatus($employeeId, $active)
{
    $sql = 'UPDATE `' . _DB_PREFIX_ . 'employee` 
            SET `active` = ' . ($active ? 1 : 0) . ' 
            WHERE `id_employee` = ' . (int)$employeeId;
    
    if (!Db::getInstance()->execute($sql)) {
        throw new Exception('Failed to update employee status');
    }
}

/**
 * 分配卖家权限
 */
function assignSellerPermissions($employeeId)
{
    $sellerProfileId = getSellerProfileId();
    
    $sql = 'UPDATE `' . _DB_PREFIX_ . 'employee` 
            SET `id_profile` = ' . (int)$sellerProfileId . ' 
            WHERE `id_employee` = ' . (int)$employeeId;
    
    if (!Db::getInstance()->execute($sql)) {
        throw new Exception('Failed to assign seller permissions');
    }
}

/**
 * 移除卖家权限
 */
function removeSellerPermissions($employeeId)
{
    // 将权限设置为最低级别或禁用
    $sql = 'UPDATE `' . _DB_PREFIX_ . 'employee` 
            SET `id_profile` = 1 
            WHERE `id_employee` = ' . (int)$employeeId;
    
    Db::getInstance()->execute($sql);
}

/**
 * 获取卖家权限配置ID
 */
function getSellerProfileId()
{
    // 查找卖家权限配置，如果不存在则创建
    $sql = 'SELECT `id_profile` FROM `' . _DB_PREFIX_ . 'profile` WHERE `name` = "Seller"';
    $profileId = Db::getInstance()->getValue($sql);
    
    if (!$profileId) {
        // 创建卖家权限配置
        $sql = 'INSERT INTO `' . _DB_PREFIX_ . 'profile` (`name`) VALUES ("Seller")';
        Db::getInstance()->execute($sql);
        $profileId = Db::getInstance()->Insert_ID();
        
        // 设置卖家权限（只允许管理产品和订单）
        $permissions = [
            'AdminProducts' => ['view' => 1, 'add' => 1, 'edit' => 1, 'delete' => 1],
            'AdminOrders' => ['view' => 1, 'add' => 0, 'edit' => 1, 'delete' => 0],
            'AdminOrdersReturn' => ['view' => 1, 'add' => 1, 'edit' => 1, 'delete' => 0],
            'AdminCustomers' => ['view' => 1, 'add' => 0, 'edit' => 0, 'delete' => 0],
            'AdminStats' => ['view' => 1, 'add' => 0, 'edit' => 0, 'delete' => 0]
        ];
        
        foreach ($permissions as $controller => $perms) {
            $sql = 'INSERT INTO `' . _DB_PREFIX_ . 'access` 
                    (`id_profile`, `id_authorization_role`, `id_tab`) 
                    SELECT ' . (int)$profileId . ', ar.id_authorization_role, t.id_tab 
                    FROM `' . _DB_PREFIX_ . 'authorization_role` ar, `' . _DB_PREFIX_ . 'tab` t 
                    WHERE t.class_name = "' . pSQL($controller) . '"';
            Db::getInstance()->execute($sql);
        }
    }
    
    return $profileId;
}

/**
 * 更新审批记录
 */
function updateApprovalRecord($sellerId, $status, $approvedBy, $approvalTime, $rejectionReason = '')
{
    // 这里应该更新外部系统的审批记录
    // 可以通过API调用或数据库更新
    
    $sql = 'INSERT INTO `' . _DB_PREFIX_ . 'seller_approvals` 
            (`seller_id`, `status`, `approved_by`, `approval_time`, `rejection_reason`, `created_at`) 
            VALUES ("' . pSQL($sellerId) . '", "' . pSQL($status) . '", "' . pSQL($approvedBy) . '", 
                    "' . pSQL($approvalTime) . '", "' . pSQL($rejectionReason) . '", NOW())
            ON DUPLICATE KEY UPDATE 
            `status` = "' . pSQL($status) . '", 
            `approved_by` = "' . pSQL($approvedBy) . '", 
            `approval_time` = "' . pSQL($approvalTime) . '", 
            `rejection_reason` = "' . pSQL($rejectionReason) . '"';
    
    Db::getInstance()->execute($sql);
}

/**
 * 存储临时密码
 */
function storeTempPassword($employeeId, $password)
{
    $sql = 'INSERT INTO `' . _DB_PREFIX_ . 'employee_temp_passwords` 
            (`id_employee`, `temp_password`, `created_at`, `expires_at`) 
            VALUES (' . (int)$employeeId . ', "' . pSQL($password) . '", NOW(), 
                    DATE_ADD(NOW(), INTERVAL 7 DAY))';
    
    Db::getInstance()->execute($sql);
}

/**
 * 发送欢迎邮件
 */
function sendWelcomeEmail($email, $sellerId)
{
    // 这里应该集成邮件发送服务
    // 可以使用PrestaShop的邮件系统或外部邮件服务
    
    $subject = 'Welcome to Baidaohui Seller Platform';
    $message = "Dear Seller,\n\nYour seller application has been approved. You can now access the seller dashboard.\n\nSeller ID: {$sellerId}\n\nBest regards,\nBaidaohui Team";
    
    // 发送邮件的具体实现
    Mail::Send(
        (int)Configuration::get('PS_LANG_DEFAULT'),
        'seller_welcome',
        $subject,
        ['seller_id' => $sellerId],
        $email,
        null,
        null,
        null,
        null,
        null,
        _PS_MAIL_DIR_,
        false,
        (int)Configuration::get('PS_SHOP_DEFAULT')
    );
}

/**
 * 发送拒绝邮件
 */
function sendRejectionEmail($email, $rejectionReason)
{
    $subject = 'Seller Application Status Update';
    $message = "Dear Applicant,\n\nWe regret to inform you that your seller application has been rejected.\n\nReason: {$rejectionReason}\n\nYou may reapply after addressing the issues mentioned above.\n\nBest regards,\nBaidaohui Team";
    
    // 发送邮件的具体实现
    Mail::Send(
        (int)Configuration::get('PS_LANG_DEFAULT'),
        'seller_rejection',
        $subject,
        ['rejection_reason' => $rejectionReason],
        $email,
        null,
        null,
        null,
        null,
        null,
        _PS_MAIL_DIR_,
        false,
        (int)Configuration::get('PS_SHOP_DEFAULT')
    );
}

// 确保创建必要的数据库表
function ensureTablesExist()
{
    // 创建卖家审批记录表
    $sql = 'CREATE TABLE IF NOT EXISTS `' . _DB_PREFIX_ . 'seller_approvals` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `seller_id` varchar(100) NOT NULL,
        `status` enum("pending","approved","rejected") DEFAULT "pending",
        `approved_by` varchar(255) NOT NULL,
        `approval_time` datetime NOT NULL,
        `rejection_reason` text,
        `created_at` datetime NOT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `seller_id` (`seller_id`)
    ) ENGINE=' . _MYSQL_ENGINE_ . ' DEFAULT CHARSET=utf8;';
    
    Db::getInstance()->execute($sql);
    
    // 创建临时密码表
    $sql = 'CREATE TABLE IF NOT EXISTS `' . _DB_PREFIX_ . 'employee_temp_passwords` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `id_employee` int(11) NOT NULL,
        `temp_password` varchar(255) NOT NULL,
        `created_at` datetime NOT NULL,
        `expires_at` datetime NOT NULL,
        `used` tinyint(1) DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `id_employee` (`id_employee`)
    ) ENGINE=' . _MYSQL_ENGINE_ . ' DEFAULT CHARSET=utf8;';
    
    Db::getInstance()->execute($sql);
}

// 初始化时确保表存在
ensureTablesExist();
?> 