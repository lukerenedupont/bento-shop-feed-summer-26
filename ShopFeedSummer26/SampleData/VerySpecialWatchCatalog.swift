import SwiftUI

/// Current watches from Very Special, captured from the official Shopify
/// Watches collection. Product identity, pricing, imagery, and destinations
/// remain bound to the merchant's canonical storefront.
enum VerySpecialWatchCatalog {
    static let storyID = "shelf-luke-6-analog-watches-desk-clocks"
    static let merchantID = "very-special-watch"
    static let sourceCollectionURL = "https://www.veryspecial.watch/collections/watches"

    private static let inventory: [(Int, String, String, String, String)] = [
        (10851731308856, "Patek Philippe Aquanaut 5066a in Steel Case on Uncut Brown Rubber Strap with Box & Papers", "57000.00", "patek-philippe-aquanaut-5066a-in-steel-case-on-uncut-brown-rubber-strap-with-box-papers", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/50661025.jpg?v=1788194619"),
        (10846429249848, "Audemars Piguet Feather 56455BA Diamond Pave Dial with Rubies in Yellow Gold Case and Bracelet", "30000.00", "audemars-piguet-feather-56455ba-diamond-pave-dial-with-rubies-in-yellow-gold-case-and-bracelet", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/YGFeather1010.jpg?v=1787936613"),
        (10844132016440, "Audemars Piguet Feather 56455BC Diamond Pave Dial with Sapphires in White Gold Case and Bracelet", "30000.00", "audemars-piguet-feather-56455bc-diamond-pave-dial-with-sapphires-in-white-gold-case-and-bracelet", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/APFeather0999.jpg?v=1787853786"),
        (10844054290744, "Audemars Piguet Cobra Black Diamond Dial in White Gold Case and Bracelet", "18500.00", "audemars-piguet-cobra-black-diamond-dial-in-white-gold-case-and-bracelet", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/APFeather0989.jpg?v=1787852210"),
        (10843979972920, "Bvlgari Serpenti Tubogas BB191TS Three Rows in Steel", "8000.00", "bvlgari-serpenti-tubogas-bb191ts-three-rows-in-steel", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/APFeather0992.jpg?v=1787850790"),
        (10837294645560, "Grand Seiko Shunbun The Vernal Equinox SBGA413G Pink MOP Dial in Titanium with Box & Papers", "6500.00", "grand-seiko-shunbun-the-vernal-equinox-sbga413g-pink-mop-dial-in-titanium-with-box-papers", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/GrandSeiko0960.jpg?v=1787679628"),
        (10836342964536, "Piaget Square 9772 in Yellow Gold Case on Leather Strap and Buckle", "4500.00", "piaget-square-9772-in-yellow-gold-case-on-leather-strap-and-buckle", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/PiagetandAquanuat0947.jpg?v=1787603938"),
        (10823937524024, "Rolex Datejust 6605 \"Serpico y Laino\" with Roulette Date Wheel in Steel & Gold on Oyster Rivet Bracelet", "20000.00", "rolex-datejust-6605-serpico-y-laino-with-roulette-date-wheel-in-steel-gold-on-oyster-rivet-bracelet", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/S_L0915.jpg?v=1786577395"),
        (10815785566520, "Rolex Day-Date 118238 Fluted Bezel Silver Dial in Yellow Gold Case and Bracelet", "27000.00", "rolex-day-date-118238-fluted-bezel-silver-dial-in-yellow-gold-case-and-bracelet", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/Panthere0894.jpg?v=1786392492"),
        (10815436030264, "Rolex Day-Date 118208 Smooth Bezel Champagne Wave Dial in Yellow Gold Case and Bracelet", "28000.00", "rolex-day-date-118208-smooth-bezel-champagne-wave-dial-in-yellow-gold-case-and-bracelet", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/118208Wave0874.jpg?v=1786375600"),
        (10805698691384, "Vacheron Constantin Overseas Dual Time 47450 in Steel Case on Rubber Strap with Box & Papers", "20000.00", "vacheron-constantin-overseas-dual-time-47450-in-steel-case-on-rubber-strap-with-box-papers", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/EllipseOnyx0853.jpg?v=1785870166"),
        (10805681815864, "Patek Philippe Golden Ellipse 3585 Automatic Back Winder with Blue Textured Dial in Yellow Gold Case", "29000.00", "patek-philippe-golden-ellipse-3585-automatic-back-winder-with-blue-textured-dial-in-yellow-gold-case", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/EllipseOnyx0845.jpg?v=1785868877"),
        (10805623914808, "Patek Philippe Ellipse 3848/900 Onyx Dial in Yellow Gold Case on Leather Strap with Patek Ellipse Buckle", "40000.00", "patek-philippe-ellipse-3848-900-onyx-dial-in-yellow-gold-case-on-leather-strap-with-patek-ellipse-buckle", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/EllipseOnyx0839.jpg?v=1785866542"),
        (10794746741048, "Rolex Submariner 16618 Black Dial in Yellow Gold with Box & Papers - New Old Stock Condition", "35000.00", "rolex-submariner-16618-black-dial-in-yellow-gold-with-box-papers-new-old-stock-condition", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/VSOP0671.jpg?v=1785181869"),
        (10770984665400, "Audemars Piguet Royal Oak Jumbo 5402 \"A-Series\" Automatic in Steel with AP Box & Papers", "105000.00", "audemars-piguet-royal-oak-jumbo-5402-a-series-automatic-in-steel-with-ap-box-and-papers", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/5402andmore05641.jpg?v=1783639455"),
        (10799973237048, "Rolex Datejust 16233 Tropical Linen Dial in Steel & Gold Case on Jubilee Bracelet", "7300.00", "rolex-datejust-16233-lemon-linen-dial-in-steel-gold-case-on-jubilee-bracelet", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/ArabicDay-Date0769.jpg?v=1785452562"),
        (10728813527352, "Piaget Braided Bracelet Watch with Lapis Dial in Yellow Gold Case and Bracelet", "18500.00", "piaget-braided-bracelet-watch-with-lapis-dial-in-yellow-gold-case-and-bracelet", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/Franck_Piaget3412.jpg?v=1781220092"),
        (10800004399416, "Cartier Panthere Small Size 4177 in Steel with Box & Papers - Unworn Condition", "5500.00", "cartier-panthere-small-size-4177-in-steel-with-box-papers-unworn-condition", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/ArabicDay-Date0796.jpg?v=1785456490"),
        (10772992360760, "A. Lange & Sohne Lange 1 101.033 in Rose Gold Grey Dial on Leather Strap and Buckle with Box & Papers", "35000.00", "a-lange-sohne-lange-1-101-033-in-rose-gold-grey-dial-on-leather-strap-and-buckle-with-box-papers", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/CityofSails0603.jpg?v=1783966843"),
        (10747965800760, "Audemars Piguet Bangle Watch in White Gold with Opal Stone Dial and Diamond Bezel", "30000.00", "audemars-piguet-bangle-watch-in-white-gold-with-opal-stone-dial-and-diamond-bezel", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/APOPAL3432.jpg?v=1782143224"),
        (10794863722808, "Franck Muller Cintree Curvex 1752 QZ in Yellow Gold Case and Bracelet", "15000.00", "franck-muller-cintree-curvex-1752-qz-in-yellow-gold-case-and-bracelet", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/VSOP0690.jpg?v=1785195863"),
        (10772989444408, "Audemars Piguet Royal Oak Chronograph 25860IS \"City of Sails\" in Titanium with Box & Papers - 300 Examples Made", "55000.00", "audemars-piguet-royal-oak-chronograph-25860is-city-of-sails-in-titanium-with-box-papers-300-examples-made", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/CityofSails0594.jpg?v=1783966292"),
        (10794842947896, "Breguet Marine 5800BA Automatic in Yellow Gold Case and Bracelet", "20000.00", "breguet-marine-5800ba-automatic-in-yellow-gold-case-and-bracelet", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/VSOP0678.jpg?v=1785194824"),
        (10794738843960, "Patek Philippe Calatrava Travel Time 5134G in White Gold with Leather Strap and Deployant Buckle with Papers", "23000.00", "patek-philippe-calatrava-travel-time-5134g-in-white-gold-with-leather-strap-and-deployant-bucke-with-papers", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/VSOP0652.jpg?v=1785180527"),
        (10683995128120, "Patek Philippe Neptune Power Reserve Moonphase 5085 in Steel with Box & Papers", "30000.00", "patek-philippe-neptune-power-reserve-moonphase-5085-in-steel-with-box-papers", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/Lange3241.jpg?v=1778100386"),
        (10770982502712, "Audemars Piguet Quantieme Perpetual Automatic 25661BA with Sapphire Case Back on Leather Strap and Buckle", "30000.00", "audemars-piguet-quantieme-perpetual-automatic-25661ba-with-sapphire-case-back-on-leather-strap-and-buckle", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/5402andmore05681.jpg?v=1783638172"),
        (10770980077880, "Rolex Day-Date 18039 Pinball Dial in White Gold Case and Bracelet", "32000.00", "rolex-day-date-18039-pinball-dial-in-white-gold-case-and-bracelet", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/5402andmore05471.jpg?v=1783637683"),
        (10800005513528, "Jaeger-LeCoultre Reverso Classic Monoface Small Seconds in Steel with Box & Papers - Unworn Condition", "7500.00", "jaeger-lecoultre-reverso-classic-monoface-small-seconds-in-steel-with-box-papers-unworn-condition", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/VSOP0697.jpg?v=1785456957"),
        (9964258459960, "Patek Philippe Rectangular 2553 in Gold with Very Special Yellow Leather Strap Strap and Patek Philippe Buckle", "17000.00", "patek-philippe-rectangular-2553-in-gold-with-signed-strap-and-buckle", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/NewCollection2977.jpg?v=1774928376"),
        (10800010264888, "Cartier Tank Must 4323 in Steel on Leather Strap and Buckle with Box & Papers", "3600.00", "cartier-tank-must-4323-in-steel-on-leather-strap-and-buckle-with-box-papers", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/ArabicDay-Date0791.jpg?v=1785458269"),
        (10666034037048, "Rolex Datejust 1601 Tropical \"Swiss Only\" Dial with Alpha Hands on Jubilee Bracelet", "7000.00", "rolex-datejust-1601-tropical-swiss-only-dial-with-alpha-hands-on-jubilee-bracelet", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/1601Tropical3167.jpg?v=1776980062"),
        (10545099342136, "Vacheron Constantin Historiques Oval in Yellow Gold Case with Signed Strap and Buckle", "10500.00", "vacheron-constantin-historiques-oval-in-yellow-gold-case-with-signed-strap-and-buckle", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/NewCollection2948.jpg?v=1774959930"),
        (10487344202040, "Rolex Daytona 116520 \"Unpolished P-Serial\" Dial Turning Creamy on Oyster Bracelet", "24000.00", "rolex-daytona-116520-unpolished-p-serial-dial-turning-creamy-on-oyster-bracelet", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/DSC09590.jpg?v=1772832027"),
        (10545115889976, "Movado Time Only in Pink Gold with Ahrens Signed Dial on Strap and Buckle", "4800.00", "movado-time-only-in-pink-gold-with-ahrens-signed-dial-on-strap-and-buckle", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/NewCollection2929.jpg?v=1774960533"),
        (10665997140280, "Vacheron Constantin Traditionnelle 87172 in Yellow Gold Case on Leather Strap and Buckle", "14500.00", "vacheron-constantin-traditionnelle-87172-in-yellow-gold-case-on-leather-strap-and-buckle-copy", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/5036andmore3135.jpg?v=1776442961"),
        (10546923372856, "Rolex Oyster Perpetual 124300 Green Dial with Box & Papers", "10500.00", "rolex-oyster-perpetual-124300-green-dial-with-box-papers", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/TigerEyeDD3015.jpg?v=1775077646"),
        (10683997618488, "Audemars Piguet Royal Oak Offshore Chronograph 25770ST with Yellow Dial and Strap", "22000.00", "audemars-piguet-royal-oak-offshore-chronograph-25770st-with-yellow-dial-and-strap", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/Lange3234.jpg?v=1778100738"),
        (10260194492728, "Louis Vuitton Monterey II Alarm Ceramic", "10000.00", "louis-vuitton-monterey-ii-alarm-ceramic", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/TANKS_TRINITY2072.jpg?v=1763592460"),
        (10545081516344, "Rolex Ladies Datejust 6905 Tiger Eye Dial on Milanese Bracelet and Bezel", "25000.00", "rolex-ladies-datejust-6905-tiger-eye-dial-on-milanese-bracelet-and-bezel", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/NewCollection2889_f69f3cab-bdbe-46d6-bcfb-4c0292263dc0.jpg?v=1774958251"),
        (10544944087352, "Patek Philippe Oval Lapis Lazuli 4290 in Yellow Gold Case and Bracelet", "35000.00", "patek-philippe-4290-yellow-gold-lapis-lazuli-on-yellow-gold-case-and-bracelet", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/NewCollection2884.jpg?v=1774931358"),
        (10544938484024, "Rolex Ladies Datejust 69178 Wood Dial in Yellow Gold Case on President Bracelet with Papers", "17000.00", "rolex-ladies-datejust-69178-with-wood-dial-on-president-bracelet", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/NewCollection2985.jpg?v=1774930141"),
        (10285594640696, "Rolex Air-King 14010 with Slate Dial and Papers", "5800.00", "rolex-air-king-with-slate-dial-and-papers", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/DJTapestry2442.jpg?v=1765406074"),
        (10478409023800, "Rolex Sea-Dweller 16600 \"Swiss Only\" on Oyster Bracelet with Box & Papers", "10000.00", "rolex-sea-dweller-16600-swiss-only-on-oyster-bracelet-with-box-papers", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/5165andmore2721.jpg?v=1772492501"),
        (10478629650744, "Cartier Tank Américaine 2489 in White Gold Case on Green Cartier Strap with Cartier Buckle", "6700.00", "cartier-tank-americaine-2489-in-white-gold-case-on-green-cartier-strap-with-cartier-buckle", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/5165andmore2680.jpg?v=1772496878"),
        (10478575976760, "Tudor Pelagos 25600TN in Titanium Case with Warranty Card", "4500.00", "tudor-pelagos-25600tn-in-titanium-case-with-warranty-card", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/5165andmore2727.jpg?v=1772496355"),
        (10796091081016, "Chanel J12 Marine Automatic in Steel with Box & Papers", "3000.00", "chanel-j12-marine-automatic-in-steel-with-box-papers", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/Bvlgari0730.jpg?v=1785274940"),
        (10796111233336, "Bvlgari FRGMT Limited Edition BB41S Automatic in Steel with Box & Papers", "3000.00", "bvlgari-frgmt-limited-edition-bb41s-automatic-in-steel-with-box-papers", "https://cdn.shopify.com/s/files/1/0711/1865/1704/files/Bvlgari0735.jpg?v=1785276358"),
    ]

    static let productReferences = inventory.map {
        FeedStory.ProductReference(merchantID: merchantID, productID: $0.0)
    }

    static let merchant = SampleMerchant(
        id: merchantID,
        name: "Very Special",
        description: "Distinctive vintage and contemporary watches selected by Very Special.",
        rating: 0,
        totalRatings: 0,
        totalReviews: 0,
        primaryColor: Color(hex: "#312012"),
        secondaryColor: Color(hex: "#F2E7D2"),
        collections: [.init(id: "watches", name: "Watches")],
        products: inventory.map { id, title, price, handle, imageURL in
            SampleMerchant.Product(
                id: id,
                title: title,
                price: price,
                handle: handle,
                productType: "Watches",
                vendor: "Very Special",
                imageURL: imageURL,
                shopURL: "https://www.veryspecial.watch/products/\(handle)",
                tags: ["canonical-catalog", "very-special-watches"],
                allImageURLs: [imageURL]
            )
        },
        featuredImageURLs: inventory.prefix(8).map { $0.4 },
        logoImageURL: nil,
        wordmarkImageURL: nil,
        coverImageURL: inventory.first?.4,
        videoURL: nil,
        coverDominantColor: "#312012",
        productCategory: "Watches"
    )
}

