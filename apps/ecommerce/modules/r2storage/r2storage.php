<?php
/**
 * R2 Storage Module for PrestaShop
 * 自动将上传图片推送到Cloudflare R2存储
 * 
 * @author Baidaohui Team
 * @version 1.0.0
 */

if (!defined('_PS_VERSION_')) {
    exit;
}

require_once _PS_MODULE_DIR_ . 'r2storage/vendor/autoload.php';

use Aws\S3\S3Client;
use Aws\Exception\AwsException;

class R2Storage extends Module
{
    private $s3Client;
    private $bucketName;
    private $cdnDomain;
    
    public function __construct()
    {
        $this->name = 'r2storage';
        $this->tab = 'administration';
        $this->version = '1.0.0';
        $this->author = 'Baidaohui Team';
        $this->need_instance = 0;
        $this->ps_versions_compliancy = [
            'min' => '1.7.0.0',
            'max' => _PS_VERSION_
        ];
        $this->bootstrap = true;

        parent::__construct();

        $this->displayName = $this->l('R2 Storage');
        $this->description = $this->l('Automatically upload images to Cloudflare R2 storage');
        $this->confirmUninstall = $this->l('Are you sure you want to uninstall R2 Storage module?');

        if (!Configuration::get('R2STORAGE_ACCOUNT_ID')) {
            $this->warning = $this->l('R2 Storage credentials are not configured');
        }
        
        $this->initializeS3Client();
    }

    /**
     * 初始化S3客户端
     */
    private function initializeS3Client()
    {
        $accountId = Configuration::get('R2STORAGE_ACCOUNT_ID');
        $accessKeyId = Configuration::get('R2STORAGE_ACCESS_KEY_ID');
        $secretAccessKey = Configuration::get('R2STORAGE_SECRET_ACCESS_KEY');
        $this->bucketName = Configuration::get('R2STORAGE_BUCKET_NAME');
        $this->cdnDomain = Configuration::get('R2STORAGE_CDN_DOMAIN');

        if ($accountId && $accessKeyId && $secretAccessKey) {
            $this->s3Client = new S3Client([
                'version' => 'latest',
                'region' => 'auto',
                'endpoint' => "https://{$accountId}.r2.cloudflarestorage.com",
                'credentials' => [
                    'key' => $accessKeyId,
                    'secret' => $secretAccessKey,
                ],
                'use_path_style_endpoint' => true,
            ]);
        }
    }

    /**
     * 模块安装
     */
    public function install()
    {
        return parent::install() &&
            $this->registerHook('actionObjectImageAddAfter') &&
            $this->registerHook('actionObjectImageUpdateAfter') &&
            $this->registerHook('actionObjectImageDeleteAfter') &&
            $this->registerHook('actionProductImageUpload') &&
            $this->registerHook('actionCategoryImageUpload') &&
            $this->createTables();
    }

    /**
     * 模块卸载
     */
    public function uninstall()
    {
        return parent::uninstall() &&
            Configuration::deleteByName('R2STORAGE_ACCOUNT_ID') &&
            Configuration::deleteByName('R2STORAGE_ACCESS_KEY_ID') &&
            Configuration::deleteByName('R2STORAGE_SECRET_ACCESS_KEY') &&
            Configuration::deleteByName('R2STORAGE_BUCKET_NAME') &&
            Configuration::deleteByName('R2STORAGE_CDN_DOMAIN') &&
            Configuration::deleteByName('R2STORAGE_AUTO_UPLOAD') &&
            Configuration::deleteByName('R2STORAGE_DELETE_LOCAL') &&
            $this->dropTables();
    }

    /**
     * 创建数据库表
     */
    private function createTables()
    {
        $sql = 'CREATE TABLE IF NOT EXISTS `' . _DB_PREFIX_ . 'r2storage_files` (
            `id_file` int(11) NOT NULL AUTO_INCREMENT,
            `local_path` varchar(255) NOT NULL,
            `r2_key` varchar(255) NOT NULL,
            `r2_url` varchar(500) NOT NULL,
            `file_size` int(11) NOT NULL,
            `mime_type` varchar(100) NOT NULL,
            `upload_date` datetime NOT NULL,
            `status` enum("uploaded","failed","deleted") DEFAULT "uploaded",
            PRIMARY KEY (`id_file`),
            UNIQUE KEY `local_path` (`local_path`),
            KEY `r2_key` (`r2_key`)
        ) ENGINE=' . _MYSQL_ENGINE_ . ' DEFAULT CHARSET=utf8;';

        return Db::getInstance()->execute($sql);
    }

    /**
     * 删除数据库表
     */
    private function dropTables()
    {
        $sql = 'DROP TABLE IF EXISTS `' . _DB_PREFIX_ . 'r2storage_files`';
        return Db::getInstance()->execute($sql);
    }

    /**
     * 配置页面
     */
    public function getContent()
    {
        $output = null;

        if (Tools::isSubmit('submit' . $this->name)) {
            $accountId = strval(Tools::getValue('R2STORAGE_ACCOUNT_ID'));
            $accessKeyId = strval(Tools::getValue('R2STORAGE_ACCESS_KEY_ID'));
            $secretAccessKey = strval(Tools::getValue('R2STORAGE_SECRET_ACCESS_KEY'));
            $bucketName = strval(Tools::getValue('R2STORAGE_BUCKET_NAME'));
            $cdnDomain = strval(Tools::getValue('R2STORAGE_CDN_DOMAIN'));
            $autoUpload = (bool)Tools::getValue('R2STORAGE_AUTO_UPLOAD');
            $deleteLocal = (bool)Tools::getValue('R2STORAGE_DELETE_LOCAL');

            if (!$accountId || !$accessKeyId || !$secretAccessKey || !$bucketName) {
                $output .= $this->displayError($this->l('All R2 credentials are required'));
            } else {
                Configuration::updateValue('R2STORAGE_ACCOUNT_ID', $accountId);
                Configuration::updateValue('R2STORAGE_ACCESS_KEY_ID', $accessKeyId);
                Configuration::updateValue('R2STORAGE_SECRET_ACCESS_KEY', $secretAccessKey);
                Configuration::updateValue('R2STORAGE_BUCKET_NAME', $bucketName);
                Configuration::updateValue('R2STORAGE_CDN_DOMAIN', $cdnDomain);
                Configuration::updateValue('R2STORAGE_AUTO_UPLOAD', $autoUpload);
                Configuration::updateValue('R2STORAGE_DELETE_LOCAL', $deleteLocal);

                $this->initializeS3Client();
                $output .= $this->displayConfirmation($this->l('Settings updated'));
            }
        }

        return $output . $this->displayForm();
    }

    /**
     * 显示配置表单
     */
    public function displayForm()
    {
        $defaultLang = (int)Configuration::get('PS_LANG_DEFAULT');

        $fieldsForm[0]['form'] = [
            'legend' => [
                'title' => $this->l('R2 Storage Settings'),
            ],
            'input' => [
                [
                    'type' => 'text',
                    'label' => $this->l('Account ID'),
                    'name' => 'R2STORAGE_ACCOUNT_ID',
                    'size' => 50,
                    'required' => true
                ],
                [
                    'type' => 'text',
                    'label' => $this->l('Access Key ID'),
                    'name' => 'R2STORAGE_ACCESS_KEY_ID',
                    'size' => 50,
                    'required' => true
                ],
                [
                    'type' => 'password',
                    'label' => $this->l('Secret Access Key'),
                    'name' => 'R2STORAGE_SECRET_ACCESS_KEY',
                    'size' => 50,
                    'required' => true
                ],
                [
                    'type' => 'text',
                    'label' => $this->l('Bucket Name'),
                    'name' => 'R2STORAGE_BUCKET_NAME',
                    'size' => 50,
                    'required' => true
                ],
                [
                    'type' => 'text',
                    'label' => $this->l('CDN Domain'),
                    'name' => 'R2STORAGE_CDN_DOMAIN',
                    'size' => 50,
                    'desc' => $this->l('e.g., assets.baidaohui.com')
                ],
                [
                    'type' => 'switch',
                    'label' => $this->l('Auto Upload'),
                    'name' => 'R2STORAGE_AUTO_UPLOAD',
                    'is_bool' => true,
                    'desc' => $this->l('Automatically upload images to R2 when they are added'),
                    'values' => [
                        [
                            'id' => 'auto_upload_on',
                            'value' => true,
                            'label' => $this->l('Enabled')
                        ],
                        [
                            'id' => 'auto_upload_off',
                            'value' => false,
                            'label' => $this->l('Disabled')
                        ]
                    ],
                ],
                [
                    'type' => 'switch',
                    'label' => $this->l('Delete Local Files'),
                    'name' => 'R2STORAGE_DELETE_LOCAL',
                    'is_bool' => true,
                    'desc' => $this->l('Delete local files after successful upload to R2'),
                    'values' => [
                        [
                            'id' => 'delete_local_on',
                            'value' => true,
                            'label' => $this->l('Enabled')
                        ],
                        [
                            'id' => 'delete_local_off',
                            'value' => false,
                            'label' => $this->l('Disabled')
                        ]
                    ],
                ],
            ],
            'submit' => [
                'title' => $this->l('Save'),
                'class' => 'btn btn-default pull-right'
            ]
        ];

        $helper = new HelperForm();
        $helper->module = $this;
        $helper->name_controller = $this->name;
        $helper->token = Tools::getAdminTokenLite('AdminModules');
        $helper->currentIndex = AdminController::$currentIndex . '&configure=' . $this->name;

        $helper->default_form_language = $defaultLang;
        $helper->allow_employee_form_lang = $defaultLang;

        $helper->title = $this->displayName;
        $helper->show_toolbar = true;
        $helper->toolbar_scroll = true;
        $helper->submit_action = 'submit' . $this->name;
        $helper->toolbar_btn = [
            'save' => [
                'desc' => $this->l('Save'),
                'href' => AdminController::$currentIndex . '&configure=' . $this->name . '&save' . $this->name .
                '&token=' . Tools::getAdminTokenLite('AdminModules'),
            ],
            'back' => [
                'href' => AdminController::$currentIndex . '&token=' . Tools::getAdminTokenLite('AdminModules'),
                'desc' => $this->l('Back to list')
            ]
        ];

        $helper->fields_value['R2STORAGE_ACCOUNT_ID'] = Configuration::get('R2STORAGE_ACCOUNT_ID');
        $helper->fields_value['R2STORAGE_ACCESS_KEY_ID'] = Configuration::get('R2STORAGE_ACCESS_KEY_ID');
        $helper->fields_value['R2STORAGE_SECRET_ACCESS_KEY'] = Configuration::get('R2STORAGE_SECRET_ACCESS_KEY');
        $helper->fields_value['R2STORAGE_BUCKET_NAME'] = Configuration::get('R2STORAGE_BUCKET_NAME');
        $helper->fields_value['R2STORAGE_CDN_DOMAIN'] = Configuration::get('R2STORAGE_CDN_DOMAIN');
        $helper->fields_value['R2STORAGE_AUTO_UPLOAD'] = Configuration::get('R2STORAGE_AUTO_UPLOAD');
        $helper->fields_value['R2STORAGE_DELETE_LOCAL'] = Configuration::get('R2STORAGE_DELETE_LOCAL');

        return $helper->generateForm($fieldsForm);
    }

    /**
     * 产品图片上传后处理
     */
    public function hookActionObjectImageAddAfter($params)
    {
        if (!Configuration::get('R2STORAGE_AUTO_UPLOAD')) {
            return;
        }

        $image = $params['object'];
        if ($image instanceof Image) {
            $this->uploadProductImage($image);
        }
    }

    /**
     * 产品图片更新后处理
     */
    public function hookActionObjectImageUpdateAfter($params)
    {
        if (!Configuration::get('R2STORAGE_AUTO_UPLOAD')) {
            return;
        }

        $image = $params['object'];
        if ($image instanceof Image) {
            $this->uploadProductImage($image);
        }
    }

    /**
     * 图片删除后处理
     */
    public function hookActionObjectImageDeleteAfter($params)
    {
        $image = $params['object'];
        if ($image instanceof Image) {
            $this->deleteFromR2($image);
        }
    }

    /**
     * 上传产品图片到R2
     */
    private function uploadProductImage($image)
    {
        if (!$this->s3Client || !$this->bucketName) {
            return false;
        }

        try {
            $productId = $image->id_product;
            $imageId = $image->id;
            
            // 获取所有图片尺寸
            $imageTypes = ImageType::getImagesTypes('products');
            
            foreach ($imageTypes as $imageType) {
                $localPath = _PS_PROD_IMG_DIR_ . Image::getImgFolderStatic($imageId) . $imageId . '-' . $imageType['name'] . '.jpg';
                
                if (file_exists($localPath)) {
                    $r2Key = "products/{$productId}/{$imageId}-{$imageType['name']}.jpg";
                    $this->uploadFileToR2($localPath, $r2Key);
                }
            }
            
            // 上传原图
            $originalPath = _PS_PROD_IMG_DIR_ . Image::getImgFolderStatic($imageId) . $imageId . '.jpg';
            if (file_exists($originalPath)) {
                $r2Key = "products/{$productId}/{$imageId}.jpg";
                $this->uploadFileToR2($originalPath, $r2Key);
            }
            
            return true;
        } catch (Exception $e) {
            PrestaShopLogger::addLog('R2Storage: Failed to upload product image: ' . $e->getMessage(), 3);
            return false;
        }
    }

    /**
     * 上传文件到R2
     */
    private function uploadFileToR2($localPath, $r2Key)
    {
        try {
            $fileContent = file_get_contents($localPath);
            $mimeType = mime_content_type($localPath);
            $fileSize = filesize($localPath);

            $result = $this->s3Client->putObject([
                'Bucket' => $this->bucketName,
                'Key' => $r2Key,
                'Body' => $fileContent,
                'ContentType' => $mimeType,
                'ACL' => 'public-read',
                'Metadata' => [
                    'original-path' => $localPath,
                    'upload-time' => date('Y-m-d H:i:s')
                ]
            ]);

            // 生成CDN URL
            $cdnUrl = $this->generateCdnUrl($r2Key);

            // 记录到数据库
            $this->recordUpload($localPath, $r2Key, $cdnUrl, $fileSize, $mimeType);

            // 如果配置了删除本地文件
            if (Configuration::get('R2STORAGE_DELETE_LOCAL')) {
                unlink($localPath);
            }

            PrestaShopLogger::addLog("R2Storage: Successfully uploaded {$localPath} to {$r2Key}", 1);
            return $cdnUrl;

        } catch (AwsException $e) {
            PrestaShopLogger::addLog('R2Storage: AWS Error: ' . $e->getMessage(), 3);
            return false;
        } catch (Exception $e) {
            PrestaShopLogger::addLog('R2Storage: Upload Error: ' . $e->getMessage(), 3);
            return false;
        }
    }

    /**
     * 生成CDN URL
     */
    private function generateCdnUrl($r2Key)
    {
        $cdnDomain = Configuration::get('R2STORAGE_CDN_DOMAIN');
        if ($cdnDomain) {
            return "https://{$cdnDomain}/{$r2Key}";
        } else {
            return "https://{$this->bucketName}.r2.dev/{$r2Key}";
        }
    }

    /**
     * 记录上传信息到数据库
     */
    private function recordUpload($localPath, $r2Key, $r2Url, $fileSize, $mimeType)
    {
        $sql = 'INSERT INTO `' . _DB_PREFIX_ . 'r2storage_files` 
                (local_path, r2_key, r2_url, file_size, mime_type, upload_date, status) 
                VALUES ("' . pSQL($localPath) . '", "' . pSQL($r2Key) . '", "' . pSQL($r2Url) . '", 
                        ' . (int)$fileSize . ', "' . pSQL($mimeType) . '", NOW(), "uploaded")
                ON DUPLICATE KEY UPDATE 
                r2_key = "' . pSQL($r2Key) . '", 
                r2_url = "' . pSQL($r2Url) . '", 
                upload_date = NOW(), 
                status = "uploaded"';

        return Db::getInstance()->execute($sql);
    }

    /**
     * 从R2删除文件
     */
    private function deleteFromR2($image)
    {
        if (!$this->s3Client || !$this->bucketName) {
            return false;
        }

        try {
            $productId = $image->id_product;
            $imageId = $image->id;
            
            // 删除所有尺寸的图片
            $imageTypes = ImageType::getImagesTypes('products');
            
            foreach ($imageTypes as $imageType) {
                $r2Key = "products/{$productId}/{$imageId}-{$imageType['name']}.jpg";
                $this->deleteR2Object($r2Key);
            }
            
            // 删除原图
            $r2Key = "products/{$productId}/{$imageId}.jpg";
            $this->deleteR2Object($r2Key);
            
            return true;
        } catch (Exception $e) {
            PrestaShopLogger::addLog('R2Storage: Failed to delete image from R2: ' . $e->getMessage(), 3);
            return false;
        }
    }

    /**
     * 删除R2对象
     */
    private function deleteR2Object($r2Key)
    {
        try {
            $this->s3Client->deleteObject([
                'Bucket' => $this->bucketName,
                'Key' => $r2Key
            ]);

            // 更新数据库状态
            $sql = 'UPDATE `' . _DB_PREFIX_ . 'r2storage_files` 
                    SET status = "deleted" 
                    WHERE r2_key = "' . pSQL($r2Key) . '"';
            Db::getInstance()->execute($sql);

            PrestaShopLogger::addLog("R2Storage: Successfully deleted {$r2Key}", 1);
            return true;

        } catch (AwsException $e) {
            PrestaShopLogger::addLog('R2Storage: Failed to delete from R2: ' . $e->getMessage(), 3);
            return false;
        }
    }

    /**
     * 获取R2文件URL
     */
    public function getR2Url($localPath)
    {
        $sql = 'SELECT r2_url FROM `' . _DB_PREFIX_ . 'r2storage_files` 
                WHERE local_path = "' . pSQL($localPath) . '" AND status = "uploaded"';
        
        return Db::getInstance()->getValue($sql);
    }

    /**
     * 批量上传现有图片
     */
    public function batchUploadExistingImages()
    {
        $images = Image::getAllImages();
        $uploadCount = 0;
        
        foreach ($images as $imageData) {
            $image = new Image($imageData['id_image']);
            if ($this->uploadProductImage($image)) {
                $uploadCount++;
            }
        }
        
        return $uploadCount;
    }
} 