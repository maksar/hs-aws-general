{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- |
-- Module: Aws.General
-- Copyright: Copyright © 2014 AlephCloud Systems, Inc.
-- License: BSD3
-- Maintainer: Lars Kuhtz <lars@alephcloud.com>
-- Stability: experimental
--
-- Bindings for AWS General Reference
--
-- /API Version: 1.0/
--
-- <http://docs.aws.amazon.com/general/latest/gr/>
--
module Aws.General
( AwsType(..)

-- * AWS General Version
, GeneralVersion(..)
, generalVersionToText
, parseGeneralVersion

-- * SignatureVersion
, SignatureVersion(..)
, signatureVersionToText
, parseSignatureVersion

-- * SignatureMethod
, SignatureMethod(..)
, signatureMethodToText
, parseSignatureMethod

-- * AWS Region
, Region(..)
, regionToText
, parseRegion

-- * AWS Account ID
, AccountId(..)
, accountIdToText
, parseAccountId

-- * AWS Canonical User ID
, CanonicalUserId(..)
, canonicalUserIdToText
, parseCanonicalUserId

-- * AWS Service Namespace
, ServiceNamespace(..)
, serviceNamespaceToText
, parseServiceNamespace

-- * AWS ARN
, Arn(..)
, arnToText
, parseArn
) where

import Control.Applicative
import Control.DeepSeq
import Control.Monad
import qualified Control.Monad.Fail as MF

import Data.Aeson (ToJSON(..), FromJSON(..), withText)
import qualified Data.Attoparsec.Text as AP
import Data.Hashable (Hashable, hashWithSalt, hashUsing)
import qualified Data.List as L
import Data.Monoid
import Data.String
import qualified Data.Text as T
import Data.Typeable

import GHC.Generics

import qualified Test.QuickCheck as Q
import Test.QuickCheck.Instances ()

import qualified Text.Parser.Char as P
import qualified Text.Parser.Combinators as P
import Text.Parser.Combinators ((<?>))
import Text.Printf

-- -------------------------------------------------------------------------- --
-- AWS Type

class AwsType a where
    toText :: (IsString b, Monoid b) => a -> b
    parse :: (MF.MonadFail m,  P.CharParsing m) => m a

    fromText :: T.Text -> Either String a
    fromText = AP.parseOnly $ parse <* P.eof

    {-# MINIMAL toText, parse #-}

-- -------------------------------------------------------------------------- --
-- General API Version

data GeneralVersion
    = GeneralVersion_1_0
    deriving (Show, Read, Eq, Ord, Enum, Bounded, Typeable, Generic)

instance NFData GeneralVersion

generalVersionToText :: (IsString a) => GeneralVersion -> a
generalVersionToText GeneralVersion_1_0 = "1.0"

parseGeneralVersion :: P.CharParsing m => m GeneralVersion
parseGeneralVersion = GeneralVersion_1_0 <$ P.text "1.0"
    <?> "General Version"

instance AwsType GeneralVersion where
    toText = generalVersionToText
    parse = parseGeneralVersion

instance Q.Arbitrary GeneralVersion where
    arbitrary = Q.elements [minBound..maxBound]

-- -------------------------------------------------------------------------- --
-- Signature Version

data SignatureVersion
    = SignatureVersion2
    | SignatureVersion4
    deriving (Show, Read, Eq, Ord, Enum, Bounded, Typeable, Generic)

instance NFData SignatureVersion

signatureVersionToText :: IsString a => SignatureVersion -> a
signatureVersionToText SignatureVersion2 = "2"
signatureVersionToText SignatureVersion4 = "4"

parseSignatureVersion :: P.CharParsing m => m SignatureVersion
parseSignatureVersion =
    SignatureVersion2 <$ P.text "2"
    <|> SignatureVersion4 <$ P.text "4"
    <?> "SignatureVersion"

instance AwsType SignatureVersion where
    toText = signatureVersionToText
    parse = parseSignatureVersion

instance Q.Arbitrary SignatureVersion where
    arbitrary = Q.elements [minBound..maxBound]

-- -------------------------------------------------------------------------- --
-- Signature Method

data SignatureMethod
    = SignatureMethodSha1
    | SignatureMethodSha256
    deriving (Show, Read, Eq, Ord, Enum, Bounded, Typeable, Generic)

instance NFData SignatureMethod

signatureMethodToText :: IsString a => SignatureMethod -> a
signatureMethodToText SignatureMethodSha1 = "HmacSHA1"
signatureMethodToText SignatureMethodSha256 = "HmacSHA256"

parseSignatureMethod :: P.CharParsing m => m SignatureMethod
parseSignatureMethod =
    SignatureMethodSha1 <$ P.text "HmacSHA1"
    <|> SignatureMethodSha256 <$ P.text "HmacSHA256"
    <?> "SignatureMethod"

instance AwsType SignatureMethod where
    toText = signatureMethodToText
    parse = parseSignatureMethod

instance Q.Arbitrary SignatureMethod where
    arbitrary = Q.elements [minBound..maxBound]

-- -------------------------------------------------------------------------- --
-- AWS Region

-- | Region
--
-- <http://docs.aws.amazon.com/general/1.0/gr/rande.html>
--
-- The relation between regions and service endpoints is not bijective for all
-- AWS services. Not all AWS services support all regions. Some services don't
-- use the concept of region at all.
--
data Region
    = ApNortheast1
    | ApSoutheast1
    | ApSoutheast2
    | EuCentral1
    | EuWest1
    | SaEast1
    | UsEast1
    | UsWest1
    | UsWest2
    | CustomEndpoint !T.Text !Int
    -- ^ To override the region settings with a custom service endpoint, e.g.
    -- for testing purpose

    deriving (Show, Read, Eq, Ord, Typeable, Generic)

instance NFData Region

regionToText :: (Monoid a, IsString a) => Region -> a
regionToText ApNortheast1 = "ap-northeast-1"
regionToText ApSoutheast1 = "ap-southeast-1"
regionToText ApSoutheast2 = "ap-southeast-2"
regionToText EuCentral1 = "eu-central-1"
regionToText EuWest1 = "eu-west-1"
regionToText SaEast1 = "sa-east-1"
regionToText UsEast1 = "us-east-1"
regionToText UsWest1 = "us-west-1"
regionToText UsWest2 = "us-west-2"
regionToText (CustomEndpoint e p) = "custom:" <> fromString (T.unpack e) <> ":" <> fromString (show p)

-- | Regions are parsed as follows:
--
-- @
-- 'ApNortheast1'   ::= "ap-northeast-1"
-- 'ApSoutheast1'   ::= "ap-southeast-1"
-- 'ApSoutheast2'   ::= "ap-southeast-2"
-- 'EuCentral1'     ::= "eu-central-1"
-- 'EuWest1'        ::= "eu-west-1"
-- 'SaEast1'        ::= "sa-east-1"
-- 'UsEast1'        ::= "us-east-1"
-- 'UsWest1'        ::= "us-west-1"
-- 'UsWest2'        ::= "us-west-2"
-- 'CustomEndpoint' ::= "custom:" 'T.Text' ":" 'Int'
-- @
--
parseRegion :: P.CharParsing m => m Region
parseRegion =
    ApNortheast1 <$ P.text "ap-northeast-1"
    <|> ApSoutheast1 <$ P.text "ap-southeast-1"
    <|> ApSoutheast2 <$ P.text "ap-southeast-2"
    <|> EuCentral1 <$ P.text "eu-central-1"
    <|> EuWest1 <$ P.text "eu-west-1"
    <|> SaEast1 <$ P.text "sa-east-1"
    <|> UsEast1 <$ P.text "us-east-1"
    <|> UsWest1 <$ P.text "us-west-1"
    <|> UsWest2 <$ P.text "us-west-2"
    <|> parseCustomEndpoint
    <?> "Region"
  where
    parseCustomEndpoint = CustomEndpoint
        <$> (fmap T.pack $ P.text "custom:" *> many (P.notChar ':'))
        <*> (fmap read $ P.text ":" *> some P.digit)

instance AwsType Region where
    toText = regionToText
    parse = parseRegion

standardRegions :: [Region]
standardRegions =
    [ ApNortheast1
    , ApSoutheast1
    , ApSoutheast2
    , EuWest1
    , EuCentral1
    , SaEast1
    , UsEast1
    , UsWest1
    , UsWest2
    ]


{-
instance FromJSON Ec2Region where
    parseJSON = withText "Ec2Region" $ either fail return ∘ readEither ∘ T.unpack

instance ToJSON Ec2Region where
    toJSON = toJSON ∘ show
-}

instance Hashable Region where
    hashWithSalt s (CustomEndpoint e p) = s `hashWithSalt` (0 :: Int) `hashWithSalt` (e, p)
    hashWithSalt s r =
        case L.elemIndex r standardRegions of
            Just i -> hashWithSalt s (succ i)
            Nothing -> hashWithSalt s (length standardRegions + 1)

instance Q.Arbitrary Region where
    arbitrary = Q.oneof
        [ Q.elements standardRegions
        , CustomEndpoint <$> arbitraryEndpoint <*> arbitraryPort
        ]
      where
        arbitraryEndpoint = fmap T.pack . Q.listOf . Q.elements $ '.' : ['a'..'z']
        arbitraryPort = Q.choose (0, 10000)

-- -------------------------------------------------------------------------- --
-- AWS Account Id

-- | AWS Account Id
--
-- <http://docs.aws.amazon.com/general/1.0/gr/acct-identifiers.html>.
--
-- This is actually a 12 digit number.
--
newtype AccountId = AccountId T.Text
    deriving (Show, Read, Eq, Ord, IsString, Typeable, Generic)

instance NFData AccountId

accountIdToText :: (IsString a) => AccountId -> a
accountIdToText (AccountId t) = fromString $ T.unpack t

parseAccountId :: P.CharParsing m => m AccountId
parseAccountId = AccountId . T.pack
    <$> P.count 12 P.digit
    <?> "Account ID"

instance AwsType AccountId where
    toText = accountIdToText
    parse = parseAccountId

instance Q.Arbitrary AccountId where
    arbitrary = AccountId . T.pack . printf "%012d" <$> Q.choose (0::Integer, 999999999999)

-- -------------------------------------------------------------------------- --
-- AWS Canonical User ID

-- | AWS Canonical User ID
--
-- <http://docs.aws.amazon.com/general/latest/gr/acct-identifiers.html>.
--
-- This is actually a long hexadecimal number
--
newtype CanonicalUserId = CanonicalUserId T.Text
    deriving (Show, Read, Eq, Ord, IsString, Typeable, Generic)

instance NFData CanonicalUserId

canonicalUserIdToText :: (IsString a) => CanonicalUserId -> a
canonicalUserIdToText (CanonicalUserId t) = fromString $ T.unpack t

parseCanonicalUserId :: P.CharParsing m => m CanonicalUserId
parseCanonicalUserId = CanonicalUserId . T.pack
    <$> some P.hexDigit
    <?> "Canonical User ID"

instance AwsType CanonicalUserId where
    toText = canonicalUserIdToText
    parse = parseCanonicalUserId

instance Q.Arbitrary CanonicalUserId where
    arbitrary = CanonicalUserId . T.pack <$> do
        i <- Q.choose (32,128)
        replicateM i (Q.elements $ ['0'..'9'] <> ['a'..'f'])

-- -------------------------------------------------------------------------- --
-- Service Namespace

-- | AWS Service Namespaces
--
-- <http://docs.aws.amazon.com/general/1.0/gr/aws-arns-and-namespaces.html#genref-aws-service-namespaces>
--
data ServiceNamespace
    = ServiceNamespaceAwsPortal
    | ServiceNamespaceAutoscaling
    | ServiceNamespaceCloudformation
    | ServiceNamespaceCloudfront
    | ServiceNamespaceCloudwatch
    | ServiceNamespaceDynamodb
    | ServiceNamespaceEc2
    -- ^ Amazon EC2 and Amazon VPC
    | ServiceNamespaceElasticbeanstalk
    | ServiceNamespaceElasticloadbalancing
    | ServiceNamespaceElasticmapreduce
    | ServiceNamespaceElasticache
    | ServiceNamespaceGlacier
    | ServiceNamespaceIam
    | ServiceNamespaceKinesis
    | ServiceNamespaceAwsMarketplaceManagement
    | ServiceNamespaceOpsworks
    | ServiceNamespaceRds
    | ServiceNamespaceRedshift
    | ServiceNamespaceRoute53
    | ServiceNamespaceS3
    | ServiceNamespaceSes
    | ServiceNamespaceSdb
    | ServiceNamespaceSqs
    | ServiceNamespaceSns
    | ServiceNamespaceStoragegateway
    | ServiceNamespaceSts
    | ServiceNamespaceSupport
    | ServiceNamespaceSwf
    | ServiceNamespaceHost
    -- ^ For testing purposes (see <http://docs.aws.amazon.com/general/1.0/gr/signature-v4-test-suite.html>)
    deriving (Show, Read, Eq, Ord, Enum, Bounded, Typeable, Generic)

instance NFData ServiceNamespace

serviceNamespaceToText :: IsString a => ServiceNamespace -> a
serviceNamespaceToText ServiceNamespaceAwsPortal = "aws-portal"
serviceNamespaceToText ServiceNamespaceAutoscaling = "autoscaling"
serviceNamespaceToText ServiceNamespaceCloudformation = "cloudformation"
serviceNamespaceToText ServiceNamespaceCloudfront = "cloudfront"
serviceNamespaceToText ServiceNamespaceCloudwatch = "cloudwatch"
serviceNamespaceToText ServiceNamespaceDynamodb = "dynamodb"
serviceNamespaceToText ServiceNamespaceEc2 = "ec2"
serviceNamespaceToText ServiceNamespaceElasticbeanstalk = "elasticbeanstalk"
serviceNamespaceToText ServiceNamespaceElasticloadbalancing = "elasticloadbalancing"
serviceNamespaceToText ServiceNamespaceElasticmapreduce = "elasticmapreduce"
serviceNamespaceToText ServiceNamespaceElasticache = "elasticache"
serviceNamespaceToText ServiceNamespaceGlacier = "glacier"
serviceNamespaceToText ServiceNamespaceIam = "iam"
serviceNamespaceToText ServiceNamespaceKinesis = "kinesis"
serviceNamespaceToText ServiceNamespaceAwsMarketplaceManagement = "aws-marketplace-management"
serviceNamespaceToText ServiceNamespaceOpsworks = "opsworks"
serviceNamespaceToText ServiceNamespaceRds = "rds"
serviceNamespaceToText ServiceNamespaceRedshift = "redshift"
serviceNamespaceToText ServiceNamespaceRoute53 = "route53"
serviceNamespaceToText ServiceNamespaceS3 = "s3"
serviceNamespaceToText ServiceNamespaceSes = "ses"
serviceNamespaceToText ServiceNamespaceSdb = "sdb"
serviceNamespaceToText ServiceNamespaceSqs = "sqs"
serviceNamespaceToText ServiceNamespaceSns = "sns"
serviceNamespaceToText ServiceNamespaceStoragegateway = "storagegateway"
serviceNamespaceToText ServiceNamespaceSts = "sts"
serviceNamespaceToText ServiceNamespaceSupport = "support"
serviceNamespaceToText ServiceNamespaceSwf = "swf"
serviceNamespaceToText ServiceNamespaceHost = "host"

parseServiceNamespace :: P.CharParsing m => m ServiceNamespace
parseServiceNamespace =
    ServiceNamespaceAwsPortal <$ P.text "aws-portal"
    <|> ServiceNamespaceAutoscaling <$ P.text "autoscaling"
    <|> ServiceNamespaceCloudformation <$ P.text "cloudformation"
    <|> ServiceNamespaceCloudfront <$ P.text "cloudfront"
    <|> ServiceNamespaceCloudwatch <$ P.text "cloudwatch"
    <|> ServiceNamespaceDynamodb <$ P.text "dynamodb"
    <|> ServiceNamespaceEc2 <$ P.text "ec2"
    <|> ServiceNamespaceElasticbeanstalk <$ P.text "elasticbeanstalk"
    <|> ServiceNamespaceElasticloadbalancing <$ P.text "elasticloadbalancing"
    <|> ServiceNamespaceElasticmapreduce <$ P.text "elasticmapreduce"
    <|> ServiceNamespaceElasticache <$ P.text "elasticache"
    <|> ServiceNamespaceGlacier <$ P.text "glacier"
    <|> ServiceNamespaceIam <$ P.text "iam"
    <|> ServiceNamespaceKinesis <$ P.text "kinesis"
    <|> ServiceNamespaceAwsMarketplaceManagement <$ P.text "aws-marketplace-management"
    <|> ServiceNamespaceOpsworks <$ P.text "opsworks"
    <|> ServiceNamespaceRds <$ P.text "rds"
    <|> ServiceNamespaceRedshift <$ P.text "redshift"
    <|> ServiceNamespaceRoute53 <$ P.text "route53"
    <|> ServiceNamespaceS3 <$ P.text "s3"
    <|> ServiceNamespaceSes <$ P.text "ses"
    <|> ServiceNamespaceSdb <$ P.text "sdb"
    <|> ServiceNamespaceSqs <$ P.text "sqs"
    <|> ServiceNamespaceSns <$ P.text "sns"
    <|> ServiceNamespaceStoragegateway <$ P.text "storagegateway"
    <|> ServiceNamespaceSts <$ P.text "sts"
    <|> ServiceNamespaceSupport <$ P.text "support"
    <|> ServiceNamespaceSwf <$ P.text "swf"
    <|> ServiceNamespaceHost <$ P.text "host"
    <?> "Service Namespace"

instance AwsType ServiceNamespace where
    toText = serviceNamespaceToText
    parse = parseServiceNamespace

instance Hashable ServiceNamespace where
     hashWithSalt = hashUsing fromEnum

instance Q.Arbitrary ServiceNamespace where
    arbitrary = Q.elements [minBound..maxBound]

-- -------------------------------------------------------------------------- --
-- ARN

-- | Amazon Resource Names
--
-- <http://docs.aws.amazon.com/general/1.0/gr/aws-arns-and-namespaces.html>
--
-- From the specification it is not clear if elements of 'arnResource'
-- can be empty. Though examples given in the specification do not inlcude
-- such a case, our parser allows it.
--
data Arn = Arn
    { arnService :: ServiceNamespace
    , arnRegion :: Maybe Region
    , arnAccount :: Maybe AccountId
    , arnResource :: [T.Text]
    -- ^ expected to be non-empty. Elements are separated by only @:@.
    -- @/@ is not treated specially.
    }
    deriving (Show, Read, Eq, Ord, Typeable, Generic)

instance NFData Arn

arnToText :: (IsString a, Monoid a) => Arn -> a
arnToText arn = "arn:aws"
    <> ":" <> serviceNamespaceToText (arnService arn)
    <> ":" <> maybe "" regionToText (arnRegion arn)
    <> ":" <> maybe "" accountIdToText (arnAccount arn)
    <> ":" <> (fromString . T.unpack) (T.intercalate ":" (arnResource arn))

parseArn :: P.CharParsing m => m Arn
parseArn = P.text "arn:aws" *> p <?> "ARN"
  where
    p = Arn
        <$> (P.char ':' *> parseServiceNamespace)
        <*> (P.char ':' *> P.optional parseRegion)
        <*> (P.char ':' *> P.optional parseAccountId)
        <*> (P.char ':' *> P.sepBy1 (T.pack <$> many (P.notChar ':')) (P.char ':'))

instance AwsType Arn where
    toText = arnToText
    parse = parseArn

instance ToJSON Arn where
    toJSON = toJSON . (arnToText :: Arn -> T.Text)

instance FromJSON Arn where
    parseJSON = withText "Arn" $ either fail return . fromText

-- | This instance if for general testing of the syntax of ARNs. For service
-- specific ARNs you should use a newtype wrapper and define an 'Arbitrary'
-- instance the satisfies the constraints of that particular services.
--
instance Q.Arbitrary Arn where
    arbitrary = Arn
        <$> Q.arbitrary
        <*> Q.arbitrary
        <*> Q.arbitrary
        <*> (map (T.filter (/= ':')) . Q.getNonEmpty <$> Q.arbitrary)

