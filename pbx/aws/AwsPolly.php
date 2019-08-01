<?php
/**
 * Created by PhpStorm.
 * User: anuj
 * Date: 20/8/18
 * Time: 12:53 PM
 */

namespace TBETool;


use Aws\Polly\PollyClient;
use Exception;

/**
 * Class AwsPolly
 * @property  PollyClient $Client
 */
class AwsPolly
{

    private $AWS_Key;
    private $AWS_Secret;
    private $AWS_Region;
    private $AWS_Version = 'latest';
    private $AWS_http_verify = false;
    private $Client;

    private $used_voice = 'Ivy';
    private $used_language = 'en-US';
    private $output_path;
    private $file_extension = 'mp3';

    private $language_voice = [
        'da-DK' => [
            'Mads',
            'Naja'
        ],
        'nl-NL' => [
            'Ruben',
            'Lotte'
        ],
        'en-AU' => [
            'Nicole',
            'Russell'
        ],
        'en-GB' => [
            'Brian',
            'Emma',
            'Amy'
        ],
        'en-IN' => [
            'Aditi',
            'Raveena'
        ],
        'en-US' => [
            'Joey',
            'Justin',
            'Matthew',
            'Ivy',
            'Joanna',
            'Kendra',
            'Kimberly',
            'Salli'
        ],
        'en-GB-WLS' => [
            'Geraint'
        ],
        'fr-FR' => [
            'Mathieu',
            'Celine',
            'Lea'
        ],
        'fr-CA' => [
            'Chantal'
        ],
        'de-DE' => [
            'Hans',
            'Marlene',
            'Vicki'
        ],
        'hi-IN' => [
            'Aditi'
        ],
        'is-IS' => [
            'Karl',
            'Dora'
        ],
        'it-IT' => [
            'Giorgio',
            'Carla'
        ],
        'ja-JP' => [
            'Takumi',
            'Mizuki',
            'Seoyeon'
        ],
        'ko-KR' => [
            'Seoyeon'
        ],
        'nb-NO' => [
            'Liv'
        ],
        'pl-PL' => [
            'Jacek',
            'Jan',
            'Ewa',
            'Maja'
        ],
        'pt-BR' => [
            'Ricardo',
            'Vitoria'
        ],
        'pt-PT' => [
            'Cristiano',
            'Ines'
        ],
        'ro-RO' => [
            'Carmen'
        ],
        'ru-RU' => [
            'Maxim',
            'Tatyana'
        ],
        'es-ES' => [
            'Enrique',
            'Conchita'
        ],
        'es-US' => [
            'Miguel',
            'Penelope'
        ],
        'sv-SE' => [
            'Astrid',
        ],
        'tr-TR' => [
            'Filiz'
        ],
        'cy-GB' => [
            'Gwyneth'
        ]
    ];

    /**
     * AwsPolly constructor.
     * @param $aws_key
     * @param $aws_secret
     * @param null $aws_region
     * @param null $aws_version
     * @param bool $aws_http_verify
     * @throws Exception
     */
    function __construct($aws_key, $aws_secret, $aws_region, $aws_version = null, $aws_http_verify = false)
    {
        /**
         * Set AWS Key
         */
        if (!empty($aws_key) || $aws_key !== null) {
            $this->setAWSKey($aws_key);
        } else {
            throw new Exception('Key is required');
        }

        /**
         * Set AWS Secret
         */
        if (!empty($aws_secret) || $aws_secret !== null) {
            $this->setAWSSecret($aws_secret);
        } else {
            throw new Exception('Secret is missing');
        }

        // set s3 region
        if (!empty($aws_region) || $aws_region !== null) {
            $this->setAWSRegion($aws_region);
        } else {
            throw new Exception('Region is missing');
        }

        // set s3 version
        if (!empty($aws_version) || $aws_version !== null) {
            $this->setAWSVersion($aws_version);
        }
        // set s3 http verify
        $this->setAWSHttpVerify($aws_http_verify);

        /**
         * Initialize AWS Client with the provided credentials
         */
        $this->setAwsClient();
    }


    /**************************
     *    S E T T E R S
     ***************************/
    /**
     * @param mixed $AWS_Key
     */
    private function setAWSKey($AWS_Key)
    {
        $this->AWS_Key = $AWS_Key;
    }

    /**
     * @param mixed $AWS_Secret
     */
    private function setAWSSecret($AWS_Secret)
    {
        $this->AWS_Secret = $AWS_Secret;
    }

    /**
     * @param mixed $AWS_Region
     */
    private function setAWSRegion($AWS_Region)
    {
        $this->AWS_Region = $AWS_Region;
    }

    /**
     * @param string $AWS_Version
     */
    public function setAWSVersion($AWS_Version)
    {
        $this->AWS_Version = $AWS_Version;
    }

    /**
     * @param bool $AWS_http_verify
     */
    public function setAWSHttpVerify($AWS_http_verify)
    {
        $this->AWS_http_verify = $AWS_http_verify;
    }

    /**
     * @param string $used_voice
     */
    public function setUsedVoice($used_voice)
    {
        $this->used_voice = $used_voice;
    }

    /**
     * @param string $used_language
     */
    public function setUsedLanguage($used_language)
    {
        $this->used_language = $used_language;
    }

    /**
     * @param mixed $output_path
     */
    public function setOutputPath($output_path)
    {
        $this->output_path = $output_path;
    }



    /*****************************
     *  G E T T E R S
     *****************************/
    /**
     * @return mixed
     */
    public function getAWSKey()
    {
        return $this->AWS_Key;
    }

    /**
     * @return mixed
     */
    public function getAWSSecret()
    {
        return $this->AWS_Secret;
    }

    /**
     * @return mixed
     */
    public function getAWSRegion()
    {
        return $this->AWS_Region;
    }

    /**
     * @return string
     */
    public function getAWSVersion()
    {
        return $this->AWS_Version;
    }

    /**
     * @return bool
     */
    public function isAWSHttpVerify()
    {
        return $this->AWS_http_verify;
    }

    /**
     * @return string
     */
    public function getUsedVoice()
    {
        return $this->used_voice;
    }

    /**
     * @return string
     */
    public function getUsedLanguage()
    {
        return $this->used_language;
    }

    /**
     * @return mixed
     */
    public function getOutputPath()
    {
        return $this->output_path;
    }

    /**
     * @return string
     */
    public function getFileExtension()
    {
        return $this->file_extension;
    }

    /**
     * Get supported voices
     */
    public function getVoices()
    {
        $voices = [];

        foreach ($this->language_voice as $language) {
            foreach ($language as $voice) {
                $voices[] = $voice;
            }
        }

        return $voices;
    }

    /**
     * Get supported languages
     */
    public function getLanguages()
    {
        $languages = [];

        foreach ($this->language_voice as $language => $value) {
            $languages[] = $language;
        }

        return $languages;
    }


    /**
     * *****************************************
     *  S 3  C L I E N T  O B J E C T
     * *****************************************
     */

    private function setAwsClient()
    {
        $client = new PollyClient([
            'version' => $this->getAWSVersion(),
            'region' => $this->getAWSRegion(),
            'http' => [
                'verify' => $this->isAWSHttpVerify()
            ],
            'credentials' => [
                'key' => $this->getAWSKey(),
                'secret' => $this->getAWSSecret()
            ]
        ]);

        $this->Client = $client;
    }

    /**
     * ***********************************************
     *    P O L L Y  M E T H O D S
     * ***********************************************
     */


    /**
     * @param $text
     * @param array $param
     * @return string
     * @throws Exception
     */
    public function textToVoice($text, $param = [])
    {
        if (empty($text))
            throw new Exception('Text is empty');

        if (!empty($param['voice']))
            $this->setUsedVoice($param['voice']);

        if (!empty($param['language']))
            $this->setUsedLanguage($param['language']);

        if (!empty($param['output_path']))
            $this->setOutputPath($param['output_path']);


        /************************
         *  Processing
         ************************/
        if (empty($this->getOutputPath()))
            throw new Exception('Output path not specified. Either set output path with setOutputPath() function or pass second parameter to this function with absolute path. eg., [\'output_path\' => \'path_to_save\']');

        if (empty($this->getUsedVoice()))
            throw new Exception('Voice is not set. Set voice by passing [\'voice\' => \'\'] in second parameter');

        if (empty($this->getUsedLanguage()))
            throw new Exception('Language is not set. Set language by passing [\'language\' => \'\'] in second parameter');

        if (!in_array($this->getUsedLanguage(), $this->getLanguages()))
            throw new Exception($this->getUsedLanguage() . ' language is not supported. use getLanguages() to see all supported languages');

        if (!in_array($this->getUsedVoice(), $this->getVoices()))
            throw new Exception($this->getUsedVoice() . ' voice is not supported. use getVoices() to see all supported voices');

        if (!in_array($this->getUsedVoice(), $this->language_voice[$this->getUsedLanguage()]))
            throw new Exception($this->getUsedVoice() . ' is not supported in language ' . $this->getUsedLanguage() . '. Supported voices are ' . implode(',', $this->language_voice[$this->getUsedLanguage()]));

        /**
         * Get file name
         */
        $file_name = $this->_getFileName();

        $voice = $this->Client->synthesizeSpeech([
            'LanguageCode' => $this->getUsedLanguage(),
            'OutputFormat' => $this->getFileExtension(),
            'Text' => $text,
            'TextType' => 'text',
            'VoiceId' => $this->getUsedVoice()
        ]);

        $voiceContent = $voice->get('AudioStream')->getContents();

        file_put_contents($file_name, $voiceContent);

        if (is_file($file_name))
            return $file_name;

        throw new Exception('File could not be created');
    }

    /**
     * Generate file name, create directory and return absolute file path
     * @return string
     */
    private function _getFileName()
    {
        $file_name = time() . '-' . str_shuffle(time()) . '.' . $this->getFileExtension();

        $this->setOutputPath(rtrim($this->getOutputPath(), '/'));

        if (!is_dir($this->getOutputPath())) {
            mkdir($this->getOutputPath(), 0777, true);
        }

        $absolute_file_path = $this->getOutputPath() . '/' . $file_name;

        return $absolute_file_path;
    }
}