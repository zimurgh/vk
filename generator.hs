{-# LANGUAGE Arrows #-}
import Text.XML.HXT.Core
import Data.Char
import Data.List
import Data.List.Split
import Data.Maybe


data ExtractedRegistry = ExtractedRegistry
  { registryVendorId   :: ExtractedVendorId
  , registryTags       :: [ExtractedTag]
  , registryStructs    :: [ExtractedStruct]
  , registryEnums      :: [ExtractedEnums]
  , registryCommands   :: [ExtractedCommands]
  , registryFeature    :: ExtractedFeature
  , registryExtensions :: [ExtractedExtension]
  } deriving (Show,Eq)


data ExtractedVendorId = ExtractedVendorId
  { vName      :: String
  , vId        :: String
  , vComment   :: Maybe String
  } deriving (Show,Eq)


data ExtractedTag = ExtractedTag
  { tName      :: String
  , tAuthor    :: String
  , tContact   :: String
  } deriving (Show,Eq)


data ExtractedEnums = ExtractedEnums
  { enumsName        :: String
  , enumsType        :: Maybe String
  , enumsNamespace   :: Maybe String
  , enumsExpand      :: Maybe String
  , enumsComment     :: Maybe String
  , enumsEnumFields  :: [ExtractedEnum]
  } deriving (Show,Eq)


data ExtractedEnum = ExtractedEnum
  { enumName     :: String
  , enumValue    :: Maybe String
  , enumBitpos   :: Maybe String
  , enumComment  :: Maybe String
  } deriving (Show,Eq)


data ExtractedCommands = ExtractedCommands
  { commands     :: [ExtractedCommand]
  } deriving (Show,Eq)


data ExtractedCommand = ExtractedCommand
  { cSuccessCodes    :: Maybe String
  , cErrorCodes      :: Maybe String
  , cQueues          :: Maybe String
  , cRenderpass      :: Maybe String
  , cCmdbufferLevel  :: Maybe String
  , cProtoName       :: String
  , cProtoType       :: ExtractedType
  , cParams          :: [ExtractedParam]
  , cValidity        :: ExtractedValidity
  } deriving (Show,Eq)


data ExtractedValidity = ExtractedValidity
  { vUses    :: Maybe [String]
  } deriving (Show,Eq)


data ExtractedParam = ExtractedParam
  { parName            :: String
  , parType            :: ExtractedType
  , parOptional        :: Maybe String
  , parLen             :: Maybe String
  , parExternSync      :: Maybe String
  , parNoAutoValidity  :: Maybe String
  } deriving (Show,Eq)


data ExtractedType = ExtractedType
  { ptypeName :: String
  , pPointer  :: Int
  } deriving (Show,Eq)


data ExtractedFeature = ExtractedFeature
  { fApi       :: String
  , fName      :: String
  , fNumber    :: String
  , fRequires  :: [ExtractedRequire]
  } deriving (Show,Eq)


data ExtractedRequire = ExtractedRequire
  { rComment   :: Maybe String
  , rTypes     :: Maybe [ExtractedRequiredType]
  , rEnums     :: Maybe [ExtractedRequiredEnum]
  , rCommands  :: Maybe [ExtractedRequiredCommand]
  } deriving (Show,Eq)


data ExtractedRequiredType = ExtractedRequiredType
  { rtName :: String
  } deriving (Show,Eq)


data ExtractedRequiredEnum = ExtractedRequiredEnum
  { reName     :: String
  , reValue    :: Maybe String
  , reOffset   :: Maybe String
  , reExtends  :: Maybe String
  , reDir      :: Maybe String
  } deriving (Show,Eq)


data ExtractedRequiredCommand = ExtractedRequiredCommand
  { rcName :: String
  } deriving (Show,Eq)


data ExtractedExtension = ExtractedExtension
  { extName :: String
  , extNumber :: String
  , extSupported :: String
  , extProtect :: Maybe String
  , extAuthor :: Maybe String
  , extContact :: Maybe String
  , extTypes :: [ExtractedRequiredType]
  , extEnums :: [ExtractedRequiredEnum]
  , extCommand :: [ExtractedRequiredCommand]
  } deriving (Show,Eq)


data ExtractedStruct = ExtractedStruct
  { sName               :: String
  , sMembers            :: [ExtractedMember]
  , sMaybeReturnedOnly  :: Maybe String
  , sMaybeValidity      :: Maybe ExtractedValidity
  } deriving (Show,Eq)

data ExtractedMember = ExtractedMember
  { mType           :: String
  , mName           :: String
  , mOptional       :: Maybe String
  , mLen            :: Maybe String
  , mNoautoValidity :: Maybe String
  } deriving (Show,Eq)

extract :: ArrowXml a => String -> a XmlTree XmlTree
extract name = hasName name <<< isElem <<< getChildren


perhaps :: ArrowIf a => a b c -> a b (Maybe c)
perhaps x = (arr Just <<< x) `orElse` constA Nothing


parseCommands :: ArrowXml a => a XmlTree ExtractedCommands
parseCommands = proc x -> do
  commandsblock <- extract "commands" -< x
  commands <- listA $ parseCommand -< commandsblock
  returnA -< ExtractedCommands commands


parseCommand :: ArrowXml a => a XmlTree ExtractedCommand
parseCommand = proc x -> do
  command <- extract "command" -< x
  maybeSuccessCode <- perhaps (getAttrValue0 "successcodes") -< command
  maybeErrorCode <- perhaps (getAttrValue0 "errorcodes") -< command
  maybeQueues <- perhaps (getAttrValue0 "queues") -< command
  maybeRenderpass <- perhaps (getAttrValue0 "renderpass") -< command
  maybeCmdbufferlevel <- perhaps (getAttrValue0 "cmdbufferlevel") -< command
  name <- getText <<< getChildren <<< extract "name" <<< extract "proto" -< command
  cType <- parseType <<< extract "proto" -< command
  params <- listA $ parseParam -< command
  maybeValidity <- parseValidity -< command
  returnA -< ExtractedCommand maybeSuccessCode maybeErrorCode maybeQueues maybeRenderpass maybeCmdbufferlevel name cType params maybeValidity


parseValidity :: ArrowXml a => a XmlTree ExtractedValidity
parseValidity = proc x -> do
  validity <- extract "validity" -< x
  uses <- perhaps (listA $ getText <<< getChildren <<< extract "usage") -< validity
  returnA -< ExtractedValidity uses


parseType :: ArrowXml a => a XmlTree ExtractedType
parseType = proc x -> do
  pType <- getText <<< getChildren <<< extract "type" -< x
  pointer <- (getText <<< getChildren) >. length . filter (== '*') . concat -< x
  returnA -< ExtractedType pType pointer


parseParam :: ArrowXml a => a XmlTree ExtractedParam
parseParam = proc x -> do
  param <- extract "param" -< x
  pName <- getText <<< getChildren <<< extract "name" -< param
  pType <- parseType -< param
  pOptional <- perhaps (getAttrValue0 "optional") -< param
  pLen <- perhaps (getAttrValue0 "len") -< param
  pExternSync <- perhaps (getAttrValue0 "externsync") -< param
  pNoAutoValidity <- perhaps (getAttrValue0 "noautovalidity") -< param
  returnA -< ExtractedParam pName pType pOptional pLen pExternSync pNoAutoValidity


parseEnums :: ArrowXml a => a XmlTree ExtractedEnums
parseEnums = proc x -> do
  enums <- extract "enums" -< x
  eName <- getAttrValue0 "name" -< enums
  maybeESType <- perhaps (getAttrValue0 "type") -< enums
  maybeESNamespace <- perhaps (getAttrValue0 "namespace") -< enums
  maybeESExpand <- perhaps (getAttrValue0 "expand") -< enums
  maybeESComment <- perhaps (getAttrValue0 "comment") -< enums
  enumFields <- listA $ parseEnum -< enums
  returnA -< ExtractedEnums eName maybeESType maybeESNamespace maybeESExpand maybeESComment enumFields


parseEnum :: ArrowXml a => a XmlTree ExtractedEnum
parseEnum = proc x -> do
  enum <- extract "enum" -< x
  name <- getAttrValue0 "name" -< enum
  maybeEValue <- perhaps (getAttrValue0 "value") -< enum
  maybeEBitpos <- perhaps (getAttrValue0 "bitpos") -< enum
  maybeEComment <- perhaps (getAttrValue0 "comment") -< enum
  returnA -< ExtractedEnum name maybeEValue maybeEBitpos maybeEComment


parseVendorId :: ArrowXml a => a XmlTree ExtractedVendorId
parseVendorId = proc x -> do
  vendorID <- extract "vendorid" -< x
  name <- getAttrValue0 "name" -< vendorID
  vid <- getAttrValue0 "id" -< vendorID
  maybeComment <- perhaps (getAttrValue0 "comment") -< vendorID
  returnA -< ExtractedVendorId name vid maybeComment


parseTag :: ArrowXml a => a XmlTree ExtractedTag
parseTag = proc x -> do
  tag <- extract "tag" -< x
  name <- getAttrValue0 "name" -< tag
  author <- getAttrValue0 "author" -< tag
  contact <- getAttrValue0 "contact"  -< tag
  returnA -< ExtractedTag name author contact


parseFeature :: ArrowXml a => a XmlTree ExtractedFeature
parseFeature = proc x -> do
  feature <- extract "feature" -< x
  api <- getAttrValue0 "api" -< feature
  name <- getAttrValue0 "name" -< feature
  number <- getAttrValue0 "number" -< feature
  requires <- listA $ parseRequire -< feature
  returnA -< ExtractedFeature api name number requires


parseRequire :: ArrowXml a => a XmlTree ExtractedRequire
parseRequire = proc x -> do
  require <- extract "require" -< x
  comment <- perhaps (getAttrValue0 "comment") -< require
  rtype <- perhaps (listA $ parseRType) -< require
  renum <- perhaps (listA $ parseREnum) -< require
  rcommand <- perhaps (listA $ parseRCommand) -< require
  returnA -< ExtractedRequire comment rtype renum rcommand


parseRType :: ArrowXml a => a XmlTree ExtractedRequiredType
parseRType = proc x -> do
  rtype <-  extract "type" -< x
  rtname <- getAttrValue0 "name" -< rtype
  returnA -< ExtractedRequiredType rtname


parseREnum :: ArrowXml a => a XmlTree ExtractedRequiredEnum
parseREnum = proc x -> do
  enum <- extract "enum" -< x
  rename <- getAttrValue0 "name" -< enum
  revalue <- perhaps (getAttrValue0 "value") -< enum
  reoffset <- perhaps (getAttrValue0 "offset") -< enum
  reextends <- perhaps (getAttrValue0 "extends") -< enum
  redir <- perhaps (getAttrValue0 "dir") -< enum
  returnA -< ExtractedRequiredEnum rename revalue reoffset reextends redir


parseRCommand :: ArrowXml a => a XmlTree ExtractedRequiredCommand
parseRCommand = proc x -> do
  command <- extract "command" -< x
  rcname <- getAttrValue0 "name" -< command
  returnA -< ExtractedRequiredCommand rcname


parseExtension :: ArrowXml a => a XmlTree ExtractedExtension
parseExtension = proc x -> do
  extension <- extract "extension" -< x
  name <- getAttrValue0 "name" -< extension
  number <- getAttrValue0 "number" -< extension
  supported <- getAttrValue0 "supported" -< extension
  maybeProtect <- perhaps (getAttrValue0 "protect") -< extension
  maybeAuthor <- perhaps (getAttrValue0 "author") -< extension
  maybeContact <- perhaps (getAttrValue0 "contact") -< extension
  maybeTypes <- listA $ parseRType <<< extract "require" -< extension
  maybeEnums <- listA $ parseREnum <<< extract "require" -< extension
  maybeCommand <- listA $ parseRCommand <<< extract "require" -< extension
  returnA -< ExtractedExtension name number supported maybeProtect maybeAuthor maybeContact maybeTypes maybeEnums maybeCommand


parseStruct :: ArrowXml a => a XmlTree ExtractedStruct
parseStruct = proc x -> do
  struct <- hasAttrValue "category" (=="struct") <<< getChildren <<< extract "types" -< x
  name <- getAttrValue0 "name" -< struct
  members <- listA $ parseMember -< struct
  maybeReturnedOnly <- perhaps (getAttrValue0 "returnedonly") -< struct
  maybeValidity <- perhaps $ parseValidity -< struct
  returnA -< ExtractedStruct name members maybeReturnedOnly maybeValidity


parseMember :: ArrowXml a => a XmlTree ExtractedMember
parseMember = proc x -> do
  member <- extract "member" -< x
  memberType <- getText <<< getChildren <<< extract "type" -< member
  memberName <- getText <<< getChildren <<< extract "name" -< member
  maybeOptional <- perhaps (getAttrValue0 "optional") -< member
  maybeLen <- perhaps (getAttrValue0 "len") -< member
  maybeNoautoValidity <- perhaps (getAttrValue0 "noautovalidity") -< member
  returnA -< ExtractedMember memberType memberName maybeOptional maybeLen maybeNoautoValidity


parseVkXml :: IOSLA (XIOState ()) XmlTree ExtractedRegistry
parseVkXml = proc x -> do
  registry <- extract "registry" -< x
  vendorids <- parseVendorId <<< extract "vendorids" -< registry
  tags <- listA $ parseTag <<< extract "tags" -< registry
  structs <- listA $ parseStruct -< registry
  enums <- listA $ parseEnums -< registry
  commands <- listA $ parseCommands -< registry
  feature <- parseFeature -< registry
  extensions <- listA $ parseExtension <<< extract "extensions" -< registry
  returnA -< ExtractedRegistry vendorids tags structs enums commands feature extensions


toCamelCase :: String -> String
toCamelCase s = concatMap (\x -> [(toUpper . head $ x)] ++ ((map toLower) . tail $ x)) . splitOn "_" $ s


enum2pattern :: String -> String -> String
enum2pattern typeName enumName =
  "pattern " ++ (toCamelCase enumName) ++ " = " ++ "(#const " ++ enumName ++ ") :: " ++ typeName ++ "\n"


vkEnumFFILanguageExtensions :: [String]
vkEnumFFILanguageExtensions = ["{-# LANGUAGE CPP #-}\n"
                     ,"{-# LANGUAGE ForeignFunctionInterface #-}\n"
                     ,"{-# LANGUAGE ScopedTypeVariables #-}\n"
                     ,"{-# LANGUAGE PatternSynonyms #-}\n"]


vkEnumFFIModuleDeclaration :: [String] -> [String]
vkEnumFFIModuleDeclaration ex = ["module Vulkan.Enum (\n"] ++ ex ++ [") where\n"]


vkEnumFFIExports :: [ExtractedEnums] -> [String]
vkEnumFFIExports e = exportEnumTypes ++ exportPatterns
    where eFields = concatMap enumsEnumFields e
          enumNames = map enumName eFields
          enumTypes = map enumsName e
          exportEnumTypes = map (\x -> "  " ++ x ++ ",\n") enumTypes
          exportPatterns = map (\x -> "  pattern " ++ (toCamelCase x) ++",\n") enumNames


vkHeaderInclude :: String
vkHeaderInclude = "#include \"vulkan.h\"\n"


vkEnumFFIImports :: [String]
vkEnumFFIImports = [ "import Data.Int\n"
                 , "import Data.Word\n" ]


vkEnumTypes :: ExtractedEnums -> String
vkEnumTypes e = "type " ++ enumsName e ++ " = " ++ "(#type " ++ enumsName e ++ ")\n"


vkFFIPatterns :: ExtractedEnums -> [String]
vkFFIPatterns e = map (enum2pattern $ enumsName e) (map enumName $ enumsEnumFields e)


vkEnumFFIBindings :: [ExtractedEnums] -> [String]
vkEnumFFIBindings e = vkEnumFFILanguageExtensions
                      ++ vkEnumFFIModuleDeclaration (vkEnumFFIExports e)
                      ++ ["\n"]
                      ++ vkEnumFFIImports
                      ++ ["\n"]
                      ++ [vkHeaderInclude]
                      ++ ["\n"]
                      ++ (map vkEnumTypes e)
                      ++ ["\n"]
                      ++ concat (intersperse ["\n"] (map vkFFIPatterns e))


getVkEnums :: ExtractedRegistry -> [ExtractedEnums]
getVkEnums registry = filter ((\x -> ((x == (Just "enum")) || (x == (Just "bitmask")))) . enumsType) (registryEnums registry)


runVkParser :: IO ExtractedRegistry
runVkParser = do
  result <- runX (readDocument [withRemoveWS yes] "vk.xml" >>> parseVkXml)
  return . head $ result


main :: IO ()
main = do
  registry <- runVkParser
  let enums = getVkEnums registry
  let structs = registryStructs registry
  --print structs
  writeFile "src/Vulkan/Enum.hsc" (concat $ vkEnumFFIBindings enums)
