--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Data.Monoid (mappend)
import           Hakyll

--- my imports
import qualified Data.Text --requires cabal 'text'
import Text.Pandoc --requires cabal 'pandoc'

import qualified Data.ByteString.Char8 --for convert str to bytestr plantuml, requires cabal 'bytestring'
import Data.ByteString.Base16 (encode, decode) -- for encoding plantuml, requires cabal 'base16-bytestring' 


import Text.Pandoc.Walk --for post-processing pandoc, requires cabal 'pandoc-types'



--------------------------------------------------------------------------------

--------------------------------------------------------------------------------MATHJAX START
--Setup Mathjax on Hakyll
--Step 0: Add "pandoc, containers" under build-depends in stack.yaml   
--Step 0: "import Text.Pandoc.Options" in site.hs
--Step 1: Get the mathjax Extensions that recognizes single $ in our pandocs
mathjaxExtensions :: Extensions
mathjaxExtensions = extensionsFromList 
                    [Ext_tex_math_dollars --  $...$ or $$...$$
                    ,Ext_tex_math_double_backslash --  \(...\) or \[...\]
                    ,Ext_latex_macros
                    ,Ext_inline_code_attributes 
                    ]
--Step 2: Setup ReaderOptions using the Extensions from Step 1
readMathjaxOptions :: ReaderOptions 
readMathjaxOptions = defaultHakyllReaderOptions
                {
                    readerExtensions = (readerExtensions defaultHakyllReaderOptions) <> mathjaxExtensions
                }
--Step 3: Setup WriterOptions
writeMathjaxOptions :: WriterOptions
--writeMathjaxOptions = defaultHakyllWriterOptions
writeMathjaxOptions = defaultHakyllWriterOptions 
                {          
                    writerSectionDivs = True
                    ,writerNumberSections  = True
                    ,writerColumns = 130
                    , writerTableOfContents = True
                   , writerTOCDepth        = 3
                   , writerHTMLMathMethod = MathJax ""
                }

---------------------------------------------------TOC
tocTemplate :: Text.Pandoc.Template Data.Text.Text
tocTemplate =
    either error id $ either (error . show) id $
    runPure $ runWithDefaultPartials $
    compileTemplate "" "<div id=\"TOC\">$toc$</div>\n$body$"

writeTOCMathjaxOptions :: WriterOptions
writeTOCMathjaxOptions = writeMathjaxOptions{
                   
                    writerTemplate        = Just tocTemplate
                
}

---------------------------------------------------END TOC

--Step 4: Build the compiler using the ReaderOption and Writer Option from Step 2, 3.
mathJaxAddedCompiler :: Compiler (Item String)
mathJaxAddedCompiler = pandocCompilerWithTransform readMathjaxOptions writeTOCMathjaxOptions addToCodeBlock
--Step 5: Replace the line "compile $ pandocCompiler" under "match "posts/*" $ do" with 
--"compiler $ mathJaxAddedCompiler"

--exclude Table of Content
mathJaxAddedCompilerExTOC :: Compiler (Item String)
mathJaxAddedCompilerExTOC = pandocCompilerWithTransform readMathjaxOptions writeMathjaxOptions addToCodeBlock

--------------------------------------------------------------------------------MATHJAX END
------------------------------------------------------------------------------ PLANTUML pandoc filter

-- strToASCII :: [Char] -> [Int]
-- --strToASCII xs = fmap ord ( filter (\x -> not $ isSpace x) xs )
-- strToASCII xs = fmap ord xs
-- asciiToHex :: [Int] -> [String]
-- asciiToHex xs = fmap (\x -> showHex x "") xs


-- plantUMLhex :: [Char] -> String 
-- plantUMLhex xs = (concat.  asciiToHex  . strToASCII) xs


-- -- replaceLF replaces markdown doublespace newlines hex with plantUML compatible newline hex
-- replaceLF :: T.Text -> T.Text 
-- replaceLF xs =  (T.replace "20200" "0a") xs


-- hexCode :: T.Text -> T.Text 
-- hexCode y = (replaceLF (T.pack ( plantUMLhex (T.unpack y))))

------------------------------------------------RAILROAD START

railroad :: Data.Text.Text -> Data.Text.Text
railroad y = Data.Text.pack("<div class='rroad'>"<> Data.Text.unpack y <> "</div>")

------------------------------------------------RAILROAD END

mhexCode :: Data.Text.Text -> String
mhexCode y = tail $ init ( show ( Data.ByteString.Base16.encode $ Data.ByteString.Char8.pack $ Data.Text.unpack y ))

planthtml :: Data.Text.Text -> Data.Text.Text 
--planthtml y = T.pack ("<figure><img src='http://www.plantuml.com/plantuml/svg/~h" <> (T.unpack $ hexCode y) <>"'></figure>") 
planthtml y = Data.Text.pack ("<figure><img src='http://www.plantuml.com/plantuml/svg/~h" <> (mhexCode $ y) <>"'></figure>") 

--Pandoc filtering, 
addToCodeBlock :: Pandoc -> Pandoc 
addToCodeBlock  = walk ftranslate 
  where ftranslate :: Block -> Block
        ftranslate (CodeBlock ("",["plantuml"],[]) txt ) = RawBlock (Format "html") (planthtml txt)
        ftranslate (CodeBlock ("",["railroad"],[]) txt ) = RawBlock (Format "html") (railroad txt)
        ftranslate x = x 

                

-------------------------------------------------------------------------------PLANTUML END

myFeedConfiguration :: FeedConfiguration
myFeedConfiguration = FeedConfiguration
    { feedTitle       = "Jason Yang: Math and Computer Science Blog"
    , feedDescription = "Programming language theory, haskell, induction, combinatorics, Energy based models, time series analysis, differential equations, stochastic calculus, trading"
    , feedAuthorName  = "Jason Yang"
    , feedAuthorEmail = "jasonyang299@gmail.com"
    , feedRoot        = "https://userjy.github.io"
    }


main :: IO ()
main = hakyll $ do
    match "images/**" $ do
        route   idRoute
        compile copyFileCompiler

    match "css/*" $ do
        route   idRoute
        compile compressCssCompiler

------------------------------CUSTOM PATTERN MATCH START
    match "lib/**" $ do
        route   idRoute
        compile copyFileCompiler

    match "fonts/*" $ do
        route   idRoute
        compile copyFileCompiler
------------------------------CUSTOM PATTERN MATCH END



    match (fromList ["about.rst", "contact.markdown"]) $ do
        route   $ setExtension "html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" defaultContext
            >>= relativizeUrls
--------------------------------------ADD ATOM RSS FEED BEGIN
    create ["atom.xml"] $ do
        route idRoute
        compile $ do
            let feedCtx = postCtx `mappend` bodyField "description"
            posts <- fmap (take 10) . recentFirst =<<
                loadAllSnapshots "posts/*" "content"
            renderAtom myFeedConfiguration feedCtx posts
    create ["rss.xml"] $ do
        route idRoute
        compile $ do
            let feedCtx = postCtx `mappend` bodyField "description"
            posts <- fmap (take 10) . recentFirst =<<
                loadAllSnapshots "posts/*" "content"
            renderRss myFeedConfiguration feedCtx posts
--------------------------------------ADD ATOM RSS FEED END
---------------------- TAGS START
    tags <- buildTags "posts/*" (fromCapture "tags/*.html")
    tagsRules tags $ \tag tagpattern -> do
        let title = "Posts tagged \"" ++ tag ++ "\""
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll tagpattern
            let ctx = constField "title" title
                    `mappend` listField "posts" (postCtxWithTags tags) (return posts)
                    `mappend` defaultContext

            makeItem ""
                >>= loadAndApplyTemplate "templates/tag.html" ctx
                >>= loadAndApplyTemplate "templates/default.html" ctx
                >>= relativizeUrls
---------------------- TAGS END
    match "posts/*" $ do
        route $ setExtension "html"
        compile $ do
            --Check TOC metadata field filled START
            ident <- getUnderlying                                 
            toc   <- getMetadataField ident "toc"             
            let chosenCompiler = case toc of
                    Nothing -> mathJaxAddedCompilerExTOC
                    Just _ -> mathJaxAddedCompiler                        
            --Check TOC metadata field filled END 
            chosenCompiler
                >>= loadAndApplyTemplate "templates/post.html"    (postCtxWithTags tags)
                >>= saveSnapshot "content"
                >>= loadAndApplyTemplate "templates/default.html" (postCtxWithTags tags)
                >>= relativizeUrls

    create ["archive.html"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            taglist <- renderTagCloud 90 130 tags
            let archiveCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    constField "title" "Archives"            `mappend`
                    constField "taglist" taglist             `mappend`
                    defaultContext

            makeItem ""
                >>= loadAndApplyTemplate "templates/archive.html" archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= relativizeUrls


    match "index.html" $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let indexCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    constField "title" "Home"                `mappend`
                    defaultContext

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls

    match "templates/*" $ compile templateBodyCompiler

--------Building sitemap START
    create ["sitemap.xml"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            singlePages <- loadAll (fromList ["about.rst", "contact.markdown"])
            let pages = posts <> singlePages
                sitemapCtx =
                    constField "root" root <> -- here
                    listField "pages" postCtx (return pages)
            makeItem ""
                >>= loadAndApplyTemplate "templates/sitemap.xml" sitemapCtx
--------Building sitemap END
--------------------------------------------------------------------------------
--root is for sitemap
root :: String
root = "https://userjy.github.io"
--

postCtx :: Context String
postCtx =
    constField "root" root `mappend` --modified for sitemap
    dateField "date" "%B %e, %Y" `mappend`
    defaultContext

--for atom
feedCtx :: Context String
feedCtx = postCtx <> bodyField "description"

--for tags
postCtxWithTags :: Tags -> Context String
postCtxWithTags tags = tagsField "tags" tags `mappend` postCtx