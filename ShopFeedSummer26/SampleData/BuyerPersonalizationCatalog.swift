import SwiftUI

/// Evidence-backed products used only by the buyer switcher prototype.
///
/// Every item below was resolved from the merchant's public Shopify catalog
/// on 2026-08-17. Keeping the canonical product ID, handle, price, and CDN
/// media together prevents a personalized shelf from quietly relabeling an
/// unrelated product. Alternate images are merchant-supplied product media;
/// none of the profile fixtures depend on generated imagery.
enum BuyerPersonalizationCatalog {
    static let stories: [FeedStory] = [
        story(
            id: "andreas-glass-hair",
            title: "Glass hair, compared properly",
            subtitle: "The exact gloss, keratin, and smoothing formulas Andreas has been comparing, kept specific and performance-led.",
            keys: ["wellness", "catalog-only-media"],
            accent: "#6A5047",
            products: [
                ref("color-wow", 7023026405568),
                ref("alfaparf-milano", 7819324817651),
                ref("lange-hair", 4530431557732),
                ref("alfaparf-milano", 9396630880499),
            ]
        ),
        story(
            id: "andreas-smooth-blowout",
            title: "A smoother blowout, step by step",
            subtitle: "Heat protection, controlled volume, and high-gloss finish—four products with distinct jobs rather than one vague bundle.",
            keys: ["wellness", "catalog-only-media"],
            accent: "#765C55",
            products: [
                ref("lange-hair", 4804878434404),
                ref("color-wow", 7023027847360),
                ref("lange-hair", 8277661745252),
                ref("lange-hair", 8144955474020),
            ]
        ),
        story(
            id: "andreas-minimal-comfort",
            title: "Comfort, stripped back",
            subtitle: "Neutral, relaxed layers from the Comfrt line Andreas viewed—simple silhouettes with the fabric and fit doing the work.",
            keys: ["style", "catalog-only-media"],
            accent: "#4D4842",
            products: [
                ref("comfrt", 7287683743788),
                ref("comfrt", 7787401936940),
                ref("comfrt", 8444835463212),
                ref("comfrt", 8298906157100),
            ]
        ),
        story(
            id: "andreas-macbook-kit",
            title: "The useful layer around a 14-inch MacBook Pro",
            subtitle: "A fitted sleeve, travel-ready power, and practical I/O for the MacBook Andreas already owns—not another laptop recommendation.",
            keys: ["design", "catalog-only-media"],
            accent: "#394047",
            products: [
                ref("tomtoc", 9691131248870),
                ref("satechi", 7353257820248),
                ref("satechi", 7485814374488),
                ref("satechi", 7485992108120),
            ]
        ),
        story(
            id: "kyle-braided-bostons",
            title: "Boston Braided, variant by variant",
            subtitle: "Current Kith for Birkenstock Boston Braided variants to compare next—Thyme, Rabbit Grey, and Ultra Blue—without collapsing Kyle's saved Taupe and Mocha pairs into generic clogs.",
            keys: ["style"],
            accent: "#66584B",
            products: [
                ref("kith", 8286022762624),
                ref("kith", 8286022959232),
                ref("kith", 8286022992000),
            ]
        ),
        story(
            id: "kyle-1890-collabs",
            title: "The 1890 collaboration shortlist",
            subtitle: "Kyle's exact Stone Island favorite beside both current Action Bronson 1890 colorways, with each collaboration and colorway named plainly.",
            keys: ["style"],
            accent: "#3D4A3D",
            products: [
                ref("kith", 8286509564032),
                ref("kith", 8286188830848),
                ref("kith", 8286188863616),
            ]
        ),
        story(
            id: "kyle-argizari-lighting",
            title: "Start with the Argizari in Sand",
            subtitle: "The exact Gantri table lamp Kyle added to cart, followed by two current Gantri table-lamp alternatives—not a generic lighting shelf.",
            keys: ["living", "design"],
            accent: "#8B7158",
            products: [
                ref("city-lights-sf", 8568483807399),
                ref("city-lights-sf", 8568484036775),
                ref("city-lights-sf", 8568484298919),
            ]
        ),
        story(
            id: "kyle-magma-suede",
            title: "The Magma suede pair Kyle just viewed",
            subtitle: "Kith's Manhattan gloves and Passenger K15 bag in the exact Magma colorway from Kyle's recent activity.",
            keys: ["style"],
            accent: "#7A3D33",
            products: [
                ref("kith", 8285610606720),
                ref("kith", 8285609853056),
            ]
        ),
        story(
            id: "tobi-xbloom-system",
            title: "The xBloom system, filled in",
            subtitle: "The machine, reusable dripper, travel case, and cup that complete the setup Tobi keeps returning to.",
            keys: ["coffee", "design"],
            accent: "#333A38",
            products: [
                ref("xbloom", 8424667807968),
                ref("xbloom", 8661606138080),
                ref("xbloom", 8528192176352),
                ref("xbloom", 9630721868000),
            ]
        ),
        story(
            id: "tobi-coffee-creatine",
            title: "Coffee and creatine, on cadence",
            subtitle: "A precise morning repeat: measured coffee, the xBloom workflow, and the creatine already in Tobi's routine.",
            keys: ["coffee", "wellness"],
            accent: "#56463B",
            products: [
                ref("promix", 6329321411),
                ref("xbloom", 9130612687072),
                ref("xbloom", 9977673482464),
                ref("xbloom", 8661606138080),
            ]
        ),
        story(
            id: "tobi-manmade-basics",
            title: "The basics that stay in rotation",
            subtitle: "Manmade's boxer brief, tee, and socks in the restrained black uniform Tobi already gravitates toward.",
            keys: ["style"],
            accent: "#303437",
            products: [
                ref("manmade", 8829694050617),
                ref("manmade", 8830054826297),
                ref("manmade", 8830181376313),
                ref("manmade", 8859392639289),
            ]
        ),
        story(
            id: "tobi-wet-shave",
            title: "A wet-shave ritual with fewer variables",
            subtitle: "One precise razor and a short preparation-to-finish routine from Henson, without the disposable clutter.",
            keys: ["wellness"],
            accent: "#48565E",
            products: [
                ref("henson-shaving", 7234770337872),
                ref("henson-shaving", 7375317008464),
                ref("henson-shaving", 7214722908240),
                ref("henson-shaving", 7375317565520),
            ]
        ),
        story(
            id: "tobi-sim-racing",
            title: "The sim-racing open loop",
            subtitle: "A coherent MOZA path from the R5 Pro base setup to pedals, wheel, and dash—specific enough to compare properly.",
            keys: ["design"],
            accent: "#202326",
            products: [
                ref("moza-racing", 10209094500672),
                ref("moza-racing", 10078348738880),
                ref("moza-racing", 10179834118464),
                ref("moza-racing", 10179832873280),
            ]
        ),
        story(
            id: "katarina-rick-owens",
            title: "Rick Owens, reduced to the essentials",
            subtitle: "Black volume, elongated lines, and one hard-edged accessory from the current SVRN assortment.",
            keys: ["style"],
            accent: "#242326",
            products: [
                ref("svrn-rick-owens", 15632596205641),
                ref("svrn-rick-owens", 15632596861001),
                ref("svrn-rick-owens", 15632596271177),
                ref("svrn-rick-owens", 15632596992073),
            ]
        ),
        story(
            id: "katarina-silver",
            title: "Silver, with a cleaner edge",
            subtitle: "Four stainless-steel chain profiles from Vitaly, from narrow herringbone to heavier rope.",
            keys: ["style"],
            accent: "#51545A",
            products: [
                ref("vitaly", 4415294537803),
                ref("vitaly", 6796258934859),
                ref("vitaly", 6756794171467),
                ref("vitaly", 6719450447947),
            ]
        ),
        story(
            id: "katarina-black-swim",
            title: "Swim in black, then one warm interruption",
            subtitle: "Matteau's spare proportions in deep black, clay, and tomato—minimal without flattening the whole edit.",
            keys: ["style"],
            accent: "#4D3732",
            products: [
                ref("matteau", 9025373044958),
                ref("matteau", 9025359675614),
                ref("matteau", 9015274733790),
                ref("matteau", 9013492023518),
            ]
        ),
        story(
            id: "katarina-rhode-routine",
            title: "The Rhode barrier routine, edited down",
            subtitle: "Hydration and barrier support first, with four products that make sense as one compact routine.",
            keys: ["wellness"],
            accent: "#6E6259",
            products: [
                ref("rhode", 8070391660782),
                ref("rhode", 7672597414126),
                ref("rhode", 8858064388334),
                ref("rhode", 8668861104366),
            ]
        ),
    ]

    static let merchants: [SampleMerchant] = [
        merchant(id: "color-wow", name: "Color Wow", domain: "colorwowhair.com", color: "#6A5047", products: [
            product(7023026405568, "Pop & Lock High Gloss Finish", "24.00", "pop-and-lock-frizzy-control-serum", "Color Wow", [
                "https://cdn.shopify.com/s/files/1/0587/5210/6688/products/CW513_PopLock_55ml_2048x2048_101f6f21-9fb3-4348-8ba5-95b65a10a889.jpg?v=1664904611",
                "https://cdn.shopify.com/s/files/1/0587/5210/6688/products/pop_lock-mainimage.jpg?v=1664904611",
            ]),
            product(7023027847360, "Dream Coat Supernatural Spray", "30.00", "dream-coat-anti-frizz-treatment", "Color Wow", [
                "https://cdn.shopify.com/s/files/1/0587/5210/6688/products/DreamCoat_200ml_main.jpg?v=1647378208",
                "https://cdn.shopify.com/s/files/1/0587/5210/6688/files/CRE-7640W_DC_PDP_Update.jpg?v=1766003465",
            ]),
            product(7023026503872, "Extra Mist-ical Shine Spray", "29.00", "flat-hair-extra-mistical", "Color Wow", [
                "https://cdn.shopify.com/s/files/1/0587/5210/6688/files/CRE-5114W_Extra_Shine_Spray_Shopify_Main_2048x2048_1.jpg?v=1698088109",
                "https://cdn.shopify.com/s/files/1/0587/5210/6688/products/modelsoextrab_a2048x2048.jpg?v=1766083837",
            ]),
            product(7482222772416, "Extra Strength Dream Coat", "32.00", "extra-strength-dream-coat", "Color Wow", [
                "https://cdn.shopify.com/s/files/1/0587/5210/6688/files/CW574_DreamCoatES_2048x2048_d12cf130-13e7-42f8-8848-69c34d344abd.jpg?v=1738332995",
                "https://cdn.shopify.com/s/files/1/0587/5210/6688/files/CRE-4934WESDCCW574.jpg?v=1772662078",
            ]),
        ]),
        merchant(id: "lange-hair", name: "L'ange Hair", domain: "langehair.com", color: "#765C55", products: [
            product(4530431557732, "Glass Hair", "30.00", "glass-hair", "L'ange Hair", [
                "https://cdn.shopify.com/s/files/1/2204/1955/files/GLASS_HAIR_Old_Design.jpg?v=1784753244",
                "https://cdn.shopify.com/s/files/1/2204/1955/files/Glass_Hair_450F_Claim_2400_Carousel_PDP_Hero_LS.jpg?v=1785945266",
            ]),
            product(4804878434404, "Le Volume", "69.00", "le-volume", "L'ange Hair", [
                "https://cdn.shopify.com/s/files/1/2204/1955/files/Le_Volume_75MM_Blush_2400_Carousel_PDP_HeroCosmoBadge_CP_2.jpg?v=1779301712",
                "https://cdn.shopify.com/s/files/1/2204/1955/files/Le_Volume_60MM_2400_Carousel_PDP_UGC_Image_Before_After_1_NM.jpg?v=1776457134",
            ]),
            product(8277661745252, "Extra Strength Glass Hair", "32.00", "extra-strength-glass-hair", "L'ange Hair", [
                "https://cdn.shopify.com/s/files/1/2204/1955/files/GLASS_HAIRExtra_Strenghth_copy.jpg?v=1784753243",
                "https://cdn.shopify.com/s/files/1/2204/1955/files/Extra_Strength_Glass_Hair_2400_Carousel_PDP_Claim_NM.jpg?v=1772749237",
            ]),
            product(8144955474020, "VolumePro Extra-Long Ceramic Ionic Barrel Round Brush", "30.00", "volumepro-extra-long-round-brush", "L'ange Hair", [
                "https://cdn.shopify.com/s/files/1/2204/1955/files/Round_Brush_65mm_2400_Carousel_PDP_Hero_on_White_NM.jpg?v=1765908666",
                "https://cdn.shopify.com/s/files/1/2204/1955/files/Round_Brush_65mm_2400_Carousel_PDP_Model_Product_NM.jpg?v=1765908666",
            ]),
        ]),
        merchant(id: "alfaparf-milano", name: "Alfaparf Milano", domain: "shopalfaparfusa.com", color: "#745F52", products: [
            product(7819324817651, "Keratin Therapy Conditioner", "30.00", "lisse-design-keratin-therapy-maintenance-conditioner", "Alfaparf Milano Professional", [
                "https://cdn.shopify.com/s/files/1/0612/7550/4883/files/8022297141435.jpg?v=1713216118",
                "https://cdn.shopify.com/s/files/1/0612/7550/4883/files/keratinlisse-B-A-Maintenance.png?v=1713216118",
            ]),
            product(9396630880499, "Keratin Therapy Liquid Glass Lamellar Water", "44.00", "keratin-therapy-liquid-glass-lamellar-water", "Alfaparf Milano Professional", [
                "https://cdn.shopify.com/s/files/1/0612/7550/4883/files/Screenshot2026-02-24at1.58.19PM.png?v=1771959529",
                "https://cdn.shopify.com/s/files/1/0612/7550/4883/files/KERATIN-THERAPY_Groupage-still-life-retail-2025.jpg?v=1771959678",
            ]),
            product(7819332944115, "Keratin Therapy Hair Oil", "50.00", "lisse-design-keratin-therapy-oil", "Alfaparf Milano Professional", [
                "https://cdn.shopify.com/s/files/1/0612/7550/4883/products/KT-LD-THE-OIL-50ML-1-2022.jpg?v=1662588665",
                "https://cdn.shopify.com/s/files/1/0612/7550/4883/files/8022297141442_1.jpg?v=1713216171",
            ]),
            product(7634996166899, "Smooth Smoothing Cream", "26.00", "alfaparf-milano-professional-semi-di-lino-smooth-smoothing-cream", "Alfaparf Milano Professional", [
                "https://cdn.shopify.com/s/files/1/0612/7550/4883/files/8022297111254_3fb6644f-f9e2-47e2-84c6-b9dab391fc88.jpg?v=1764614448",
                "https://cdn.shopify.com/s/files/1/0612/7550/4883/files/8022297111254_2.jpg?v=1764614448",
            ]),
        ]),
        merchant(id: "comfrt", name: "Comfrt", domain: "comfrt.com", color: "#514941", products: [
            product(7287683743788, "Minimalist Hoodie – Mega", "39.00", "minimalist-hoodie", "Comfrt", [
                "https://cdn.shopify.com/s/files/1/0569/4029/8284/files/Walnut.jpg?v=1718878184",
                "https://cdn.shopify.com/s/files/1/0569/4029/8284/files/Untitleddesign_8_9eed4a70-90f2-456e-b715-5f88223cf745.jpg?v=1718878307",
            ]),
            product(7787401936940, "Minimalist Straight Leg Sweatpants", "29.00", "minimalist-straight-leg-sweatpants", "Comfrt", [
                "https://cdn.shopify.com/s/files/1/0569/4029/8284/files/2_3805b92e-2828-4400-81b7-7b95fbfdcaad.jpg?v=1740749561",
                "https://cdn.shopify.com/s/files/1/0569/4029/8284/files/6_d0eb8b7e-873d-412d-9f1d-33616fee5dc3.jpg?v=1740749561",
            ]),
            product(8444835463212, "Minimalist 7-inch Shorts", "39.00", "minimalist-7-shorts", "Comfrt", [
                "https://cdn.shopify.com/s/files/1/0569/4029/8284/files/6_430587f6-cc01-485f-a2b4-9338196e672e.jpg?v=1785974801",
                "https://cdn.shopify.com/s/files/1/0569/4029/8284/files/2_68b7accf-b2c3-4cb2-bff8-12d9be18c52b.jpg?v=1785975301",
            ]),
            product(8298906157100, "Halo Lightweight Hoodie – Mega", "49.00", "halo-lightweight-oversized-hoodie", "Comfrt", [
                "https://cdn.shopify.com/s/files/1/0569/4029/8284/files/20_7.jpg?v=1781554191",
                "https://cdn.shopify.com/s/files/1/0569/4029/8284/files/22_5.jpg?v=1781554191",
            ]),
        ]),
        merchant(id: "satechi", name: "Satechi", domain: "satechi.net", color: "#4A5055", products: [
            product(7353257820248, "Dual Dock Stand with NVMe SSD Enclosure", "169.99", "dual-dock-stand-docking-station-with-nvme-ssd-enclosure", "Satechi", [
                "https://cdn.shopify.com/s/files/1/1520/4366/products/dual-dock-stand-docking-station-with-nvme-ssd-enclosure-satechi-205400.jpg?v=1762441341",
                "https://cdn.shopify.com/s/files/1/1520/4366/products/dual-dock-stand-docking-station-with-nvme-ssd-enclosure-satechi-376477.jpg?v=1692126494",
            ]),
            product(7485814374488, "USB-C Multiport Adapter 8K with Ethernet V3", "99.99", "usb-c-multiport-adapter-8k-with-ethernet-v3", "Satechi", [
                "https://cdn.shopify.com/s/files/1/1520/4366/files/usb-c-multiport-adapter-8k-with-ethernet-v3-adapters-satechi-space-gray-103916.png?v=1762441518",
                "https://cdn.shopify.com/s/files/1/1520/4366/files/usb-c-multiport-adapter-8k-with-ethernet-v3-adapters-satechi-347660.png?v=1709585540",
            ]),
            product(7485992108120, "145W USB-C 4-Port GaN Travel Charger", "119.99", "145w-usb-c-4-port-gan-travel-charger", "Satechi", [
                "https://cdn.shopify.com/s/files/1/1520/4366/files/145w-usb-c-4-port-gan-travel-charger-charging-stations-satechi-988772.png?v=1763147415",
                "https://cdn.shopify.com/s/files/1/1520/4366/files/145w-usb-c-4-port-gan-travel-charger-wall-chargers-satechi-680630.webp?v=1763147415",
            ]),
            product(7485999022168, "Stand & Hub for Mac Mini / Studio with NVMe SSD Enclosure", "99.99", "stand-hub-for-mac-mini-studio-with-nvme-ssd-enclosure", "Satechi", [
                "https://cdn.shopify.com/s/files/1/1520/4366/files/stand-hub-for-mac-mini-studio-with-nvme-ssd-enclosure-stands-hubs-satechi-998512.webp?v=1762441521",
                "https://cdn.shopify.com/s/files/1/1520/4366/files/stand-hub-for-mac-mini-studio-with-nvme-ssd-enclosure-stands-hubs-satechi-503780.webp?v=1751567466",
            ]),
        ]),
        merchant(id: "tomtoc", name: "tomtoc", domain: "tomtoc.com", color: "#34393E", products: [
            product(9691131248870, "Defender-A42 Premium Laptop Shoulder Bag for 14-inch MacBook Pro", "55.99", "defender-a42-premium-laptop-shoulder-bag-for-14-inch-macbook-pro", "tomtoc", [
                "https://cdn.shopify.com/s/files/1/0256/7979/0179/files/20260512-143246.jpg?v=1778578767",
                "https://cdn.shopify.com/s/files/1/0256/7979/0179/files/1_02d59a0e-e33a-4395-a67f-ca6c4c7a4b85.jpg?v=1776755740",
            ]),
            product(9702687998182, "Essence-A35 Protective Laptop Sleeve for 13.5–14.4-inch Laptop", "37.99", "essence-a35-protective-laptop-sleeve-for-13-5-14-4-inch-laptop", "tomtoc", [
                "https://cdn.shopify.com/s/files/1/0256/7979/0179/files/1_f8c4c0f2-ba6e-43b5-8ea8-c5bb1da4e918.jpg?v=1772684393",
                "https://cdn.shopify.com/s/files/1/0256/7979/0179/files/23_125baf83-d51e-476d-b435-61c707514207.jpg?v=1777456309",
            ]),
            product(9661687988454, "Essence-A34 Protective Laptop Bag for 14-inch MacBook Pro", "43.99", "essence-a34-briefcase-bag-for-14-inch-macbook-pro", "tomtoc", [
                "https://cdn.shopify.com/s/files/1/0256/7979/0179/files/1_29d1d03d-f224-4038-bad5-bd5fcf5ce01c.jpg?v=1776407350",
                "https://cdn.shopify.com/s/files/1/0256/7979/0179/files/2_4cfa68fa-1f2c-4aa9-aebb-617f2caca95e.jpg?v=1772684665",
            ]),
        ]),
        merchant(id: "kith", name: "Kith", domain: "kith.com", color: "#4B423B", products: [
            product(8286022762624, "MADE-TO-ORDER | Kith for Birkenstock Boston Braided – Thyme – PH", "295.00", "br1032180-ph", "Kith", [
                "https://cdn.shopify.com/s/files/1/0094/2252/files/BR1032180-Front_601a0e5a-659b-4df2-b637-4eabbb253baf.jpg?v=1764956655",
                "https://cdn.shopify.com/s/files/1/0094/2252/files/BR1032180-Back_1406a04c-9230-447c-9a0b-730e144a34e5.jpg?v=1764956655",
            ]),
            product(8286022959232, "MADE-TO-ORDER | Kith for Birkenstock Boston Braided – Rabbit Grey – PH", "295.00", "br1032161-ph", "Kith", [
                "https://cdn.shopify.com/s/files/1/0094/2252/files/BR1032161-Front_04141c81-c413-4a9f-a7ba-3bcdb7abe02c.jpg?v=1764956714",
                "https://cdn.shopify.com/s/files/1/0094/2252/files/BR1032161-Back_37659ce8-0aca-4376-b8f3-b775365c1534.jpg?v=1764956714",
            ]),
            product(8286022992000, "MADE-TO-ORDER | Kith for Birkenstock Boston Braided – Ultra Blue – PH", "295.00", "br1032170-ph", "Kith", [
                "https://cdn.shopify.com/s/files/1/0094/2252/files/BR1032170-Front_d9adf552-d7d8-48f7-9270-11a28709861f.jpg?v=1764956655",
                "https://cdn.shopify.com/s/files/1/0094/2252/files/BR1032170-Back_b5b9e7fa-8b9c-44f6-8db2-c0bfa6e7e60d.jpg?v=1764956654",
            ]),
            product(8286509564032, "New Balance x Stone Island ABZORB 1890 – Deep Forest / Olive Green", "250.00", "nbu1890st", "New Balance", [
                "https://cdn.shopify.com/s/files/1/0094/2252/files/5476753459_sd1.jpg?v=1780510881",
                "https://cdn.shopify.com/s/files/1/0094/2252/files/20-05-2026-JW_U1890ST_2_1.jpg?v=1780510881",
            ]),
            product(8286188830848, "New Balance x Action Bronson 1890 – Blue / Grey", "200.00", "nbu18908bn", "New Balance", [
                "https://cdn.shopify.com/s/files/1/0094/2252/files/NBU18908BNNewBalanceActionBronson1890Blue_0381.jpg?v=1770835668",
                "https://cdn.shopify.com/s/files/1/0094/2252/files/NBU18908BNNewBalanceActionBronson1890Blue_0382.jpg?v=1770835668",
            ]),
            product(8286188863616, "New Balance x Action Bronson 1890 – Brown / Blue", "200.00", "nbu18901dp", "New Balance", [
                "https://cdn.shopify.com/s/files/1/0094/2252/files/NBU18901DPNewBalanceActionBronson1890White_0388.jpg?v=1770835641",
                "https://cdn.shopify.com/s/files/1/0094/2252/files/NBU18901DPNewBalanceActionBronson1890White_0390.jpg?v=1770835641",
            ]),
            product(8285610606720, "Kith Manhattan Suede Gloves – Magma", "150.00", "khm10099-601", "Kith", [
                "https://cdn.shopify.com/s/files/1/0094/2252/files/KHM10099-601-Front.jpg?v=1755120301",
                "https://cdn.shopify.com/s/files/1/0094/2252/files/KHM10099-601-Back.jpg?v=1755120302",
            ]),
            product(8285609853056, "Kith Monogram Suede Passenger K15 Bag – Magma", "275.00", "khm040234-601", "Kith", [
                "https://cdn.shopify.com/s/files/1/0094/2252/files/KHM040234-601-Front.jpg?v=1755120289",
                "https://cdn.shopify.com/s/files/1/0094/2252/files/KHM040234-601-Back.jpg?v=1755120288",
            ]),
        ]),
        merchant(id: "city-lights-sf", name: "City Lights SF", domain: "citylightssf.com", color: "#8B7158", products: [
            product(8568483807399, "Argizari Table Lamp", "248.00", "argizari-table-lamp-by-gantri", "Gantri", [
                "https://cdn.shopify.com/s/files/1/0503/4239/6071/files/gantri-argizari-table-lamp-082325-01a.jpg?v=1755910479",
                "https://cdn.shopify.com/s/files/1/0503/4239/6071/files/gantri-argizari-table-lamp-lifestyle-01_edd74045-dc8e-40c1-a5b5-c33e2c2ad249.jpg?v=1755910479",
            ]),
            product(8568484036775, "Smoothy Table Lamp", "398.00", "smoothy-table-lamp-by-gantri", "Gantri", [
                "https://cdn.shopify.com/s/files/1/0503/4239/6071/files/gantri-smoothy-table-lamp-082325-01a.jpg?v=1755910289",
                "https://cdn.shopify.com/s/files/1/0503/4239/6071/files/gantri-smoothy-table-lamp-lifestyle-01_83ea583f-c146-435c-9a48-d23d17693e09.jpg?v=1755910289",
            ]),
            product(8568484298919, "Gio Table Lamp", "398.00", "gio-table-lamp-by-gantri", "Gantri", [
                "https://cdn.shopify.com/s/files/1/0503/4239/6071/files/gantri-gio-table-lamp-082325-01a.jpg?v=1755910244",
                "https://cdn.shopify.com/s/files/1/0503/4239/6071/files/gantri-gio-table-lamp-lifestyle-01_83fe46ec-8dcd-43b9-87db-97bb25bea5e9.jpg?v=1755910244",
            ]),
            product(8568483905703, "Cora 10259 Pendant Light", "498.00", "cora-10259-pendant-light-by-gantri", "Gantri", [
                "https://cdn.shopify.com/s/files/1/0503/4239/6071/files/gantri-cora-10259-pendant-light-082325-01a.jpg?v=1755910386",
                "https://cdn.shopify.com/s/files/1/0503/4239/6071/files/gantri-cora-10259-pendant-light-lifestyle-01_dae866a0-a7b0-4627-b7a9-053c788051d7.jpg?v=1755910386",
            ]),
            product(8568483872935, "Croissant Pendant Light", "598.00", "croissant-pendant-light-by-gantri", "Gantri", [
                "https://cdn.shopify.com/s/files/1/0503/4239/6071/files/gantri-croissant-pendant-light-082325-01a.jpg?v=1755910427",
                "https://cdn.shopify.com/s/files/1/0503/4239/6071/files/gantri-croissant-pendant-light-lifestyle-01_01b63c06-1319-4b3d-b7ea-00bd8f2bbeda.jpg?v=1755910427",
            ]),
            product(8568484004007, "Pendulum 10268 Pendant Light", "498.00", "pendulum-10268-pendant-light-by-gantri", "Gantri", [
                "https://cdn.shopify.com/s/files/1/0503/4239/6071/files/gantri-pendulum-10268-pendant-light-082325-01a.jpg?v=1755910347",
                "https://cdn.shopify.com/s/files/1/0503/4239/6071/files/gantri-pendulum-10268-pendant-light-lifestyle-01_0322874f-93dc-4cff-a752-6945aef6d6bf.jpg?v=1755910347",
            ]),
            product(8568483840167, "Bamboo Pendant Light", "348.00", "bamboo-pendant-light-by-gantri", "Gantri", [
                "https://cdn.shopify.com/s/files/1/0503/4239/6071/files/gantri-bamboo-pendant-light-01a_10da7324-0465-4d46-bc52-ce138685da1b.jpg?v=1754979114",
                "https://cdn.shopify.com/s/files/1/0503/4239/6071/files/gantri-bamboo-pendant-light-lifestyle-01_4c036da3-f519-4f86-8503-8e86cebbe451.jpg?v=1754979118",
            ]),
            product(8568484495527, "Jai Pendant Light", "498.00", "jai-pendant-light-by-gantri", "Gantri", [
                "https://cdn.shopify.com/s/files/1/0503/4239/6071/files/gantri-jai-pendant-light-082325-01a.jpg?v=1755910194",
                "https://cdn.shopify.com/s/files/1/0503/4239/6071/files/gantri-jai-pendant-light-lifestyle-01_5e2c7aa9-b683-42da-9add-c8347b039944.jpg?v=1755910194",
            ]),
        ]),
        merchant(id: "xbloom", name: "xBloom", domain: "xbloom.com", color: "#353B39", products: [
            product(8424667807968, "xBloom Studio", "599.00", "xbloom-studio", "xBloom", [
                "https://cdn.shopify.com/s/files/1/0611/5704/8544/files/xbloom_Studio_Midnight_Black_05.webp?v=1777343272",
                "https://cdn.shopify.com/s/files/1/0611/5704/8544/files/xbloom_Studio_Midnight_Black_01.webp?v=1777343051",
            ]),
            product(8661606138080, "Omni Dripper 2", "39.00", "omni-dripper-2-for-xbloom-studio", "xBloom", [
                "https://cdn.shopify.com/s/files/1/0611/5704/8544/files/Omni_Dripper_White_1.png?v=1769588651",
                "https://cdn.shopify.com/s/files/1/0611/5704/8544/files/Omni_Dripper_clear_2.png?v=1777429673",
            ]),
            product(8528192176352, "Studio Travel Case", "349.00", "xbloom-studio-travel-case", "xBloom", [
                "https://cdn.shopify.com/s/files/1/0611/5704/8544/files/Studio_Travel_Case.webp?v=1777430088",
                "https://cdn.shopify.com/s/files/1/0611/5704/8544/files/Studio_Travel_Case_Interior.webp?v=1777016515",
            ]),
            product(9630721868000, "Bouba Coffee Cup – Special Edition Black", "67.00", "bouba-coffee-cup-special-edition-black", "Ni Wares", [
                "https://cdn.shopify.com/s/files/1/0611/5704/8544/files/Bouba400mlCoffeeCup-SpecialEditionBlack.png?v=1774507393",
                "https://cdn.shopify.com/s/files/1/0611/5704/8544/files/Bouba_400ml_Coffee_Cup_-_Special_Edition_Black-1.png?v=1774514865",
            ]),
            product(9130612687072, "The Future Seasonal – Strawberry Shortcake", "20.00", "the-future-seasonal-rotation", "Black & White Coffee", [
                "https://cdn.shopify.com/s/files/1/0611/5704/8544/files/Black_White_Coffee_lid.png?v=1777432268",
                "https://cdn.shopify.com/s/files/1/0611/5704/8544/files/xpod_anatomy.png?v=1776410074",
            ]),
            product(9977673482464, "Colombia Alto Naranjal", "23.00", "alto-naranjal", "La Cabra", [
                "https://cdn.shopify.com/s/files/1/0611/5704/8544/files/La_Cabra_lid.png?v=1777432436",
                "https://cdn.shopify.com/s/files/1/0611/5704/8544/files/xpod_anatomy_d43c9ef2-11f4-47b8-a3c0-faa5fed40669.png?v=1771998100",
            ]),
        ]),
        merchant(id: "promix", name: "Promix", domain: "promixnutrition.com", color: "#3D433E", products: [
            product(6329321411, "Non-GMO Creatine", "59.00", "creatine", "Promix Nutrition", [
                "https://cdn.shopify.com/s/files/1/0507/9565/products/promix-unflavored-creatine.png?v=1762197909",
                "https://cdn.shopify.com/s/files/1/0507/9565/files/1-promix-creatine-stick-packs.png?v=1722971522",
            ]),
        ]),
        merchant(id: "manmade", name: "Manmade", domain: "manmadebrand.com", color: "#30363B", products: [
            product(8829694050617, "The Boxer Brief", "24.00", "the-boxer-brief", "Manmade", [
                "https://cdn.shopify.com/s/files/1/0838/9666/4377/files/BB-Black-05.jpg?v=1762197913",
                "https://cdn.shopify.com/s/files/1/0838/9666/4377/files/BB-Black-01.jpg?v=1762368141",
            ]),
            product(8830054826297, "The T-Shirt", "48.00", "t-shirt", "Manmade", [
                "https://cdn.shopify.com/s/files/1/0838/9666/4377/files/blk-tee-d9bg__84028.jpg?v=1769538363",
                "https://cdn.shopify.com/s/files/1/0838/9666/4377/files/TShirt-Black-01__74722.jpg?v=1752158354",
            ]),
            product(8830181376313, "The Crew Sock", "12.50", "crew-sock", "Manmade", [
                "https://cdn.shopify.com/s/files/1/0838/9666/4377/files/Manmade-CrewSock-Black-Invisible.jpg?v=1755100224",
                "https://cdn.shopify.com/s/files/1/0838/9666/4377/files/pdp-socks-crew-black-01.jpg?v=1762542615",
            ]),
            product(8859392639289, "8-Pack Crew Socks", "92.00", "8-pack-crew-socks", "Manmade", [
                "https://cdn.shopify.com/s/files/1/0838/9666/4377/files/pdp-socks-crew-mix-00.png?v=1762197920",
                "https://cdn.shopify.com/s/files/1/0838/9666/4377/files/pdp-socks-crew-black-02.jpg?v=1755100224",
            ]),
        ]),
        merchant(id: "henson-shaving", name: "Henson Shaving", domain: "hensonshaving.com", color: "#4B5961", products: [
            product(7234770337872, "The Henson Razor", "79.00", "the-henson-razor", "Henson Shaving", [
                "https://cdn.shopify.com/s/files/1/0269/8025/3776/files/silver-pdp-new.jpg?v=1771622103",
                "https://cdn.shopify.com/s/files/1/0269/8025/3776/files/Product_Feature_Images_1_Overview_v2_TINY.jpg?v=1771622103",
                "https://cdn.shopify.com/s/files/1/0269/8025/3776/files/Product_Feature_Images_6_Lifestyle_Male_TINY.jpg?v=1767809200",
            ]),
            product(7375317008464, "The Protect Shave Cream", "19.99", "protect-shave-cream-can", "Henson Shaving", [
                "https://cdn.shopify.com/s/files/1/0269/8025/3776/files/protect4x5-pdp-v02.jpg?v=1767809498",
                "https://cdn.shopify.com/s/files/1/0269/8025/3776/files/creaminhand.jpg?v=1767809498",
            ]),
            product(7214722908240, "The Shave Brush", "49.99", "shave-brush", "Henson Shaving", [
                "https://cdn.shopify.com/s/files/1/0269/8025/3776/files/henson-brush-pdp-01.jpg?v=1767809221",
                "https://cdn.shopify.com/s/files/1/0269/8025/3776/files/Shave_Brush_01_1080x1350-v3.jpg?v=1767809221",
            ]),
            product(7375317565520, "The Restore Post-Shave Balm", "15.99", "restore-post-shave-balm-can", "Henson Shaving", [
                "https://cdn.shopify.com/s/files/1/0269/8025/3776/files/restore4x5-pdp-v02.jpg?v=1767809258",
                "https://cdn.shopify.com/s/files/1/0269/8025/3776/files/RESTORE_FINAL.png?v=1767809258",
            ]),
        ]),
        merchant(id: "moza-racing", name: "MOZA Racing", domain: "mozaracing.com", color: "#24272A", products: [
            product(10209094500672, "MOZA R5 Pro Racing Simulator", "549.00", "r5-pro-bundle", "MOZA Racing", [
                "https://cdn.shopify.com/s/files/1/0937/0802/6176/files/moza_r5_pro_bundle_1.png?v=1785492988",
                "https://cdn.shopify.com/s/files/1/0937/0802/6176/files/R5Pro_base.png?v=1784773749",
                "https://mozaracing.com/cdn/shop/files/r5_pro_block_1_m.png",
            ]),
            product(10078348738880, "MOZA SRP2 Pedals", "219.00", "srp2-pedals", "MOZA Racing", [
                "https://cdn.shopify.com/s/files/1/0937/0802/6176/files/MOZA_SRP2_Pedals_Throttle_Brake_-1.png?v=1774427805",
                "https://cdn.shopify.com/s/files/1/0937/0802/6176/files/MOZA_SRP2_Pedals_Throttle_Brake_-2.png?v=1774530985",
            ]),
            product(10179834118464, "MOZA CS Pro Steering Wheel", "459.00", "cs-pro-wheel", "MOZA Racing", [
                "https://cdn.shopify.com/s/files/1/0937/0802/6176/files/moza-cs-pro-steering-wheel-front_1231d638-fb78-426b-a50b-7bf6ca0f2282.jpg?v=1783432760",
                "https://cdn.shopify.com/s/files/1/0937/0802/6176/files/moza-cs-pro-steering-wheel-front-left-angle.jpg?v=1783432760",
            ]),
            product(10179832873280, "MOZA CM2 HD Racing Dash", "279.00", "cm2-dash", "MOZA Racing", [
                "https://cdn.shopify.com/s/files/1/0937/0802/6176/files/CM2-1.webp?v=1783395753",
                "https://cdn.shopify.com/s/files/1/0937/0802/6176/files/CM2-2.webp?v=1783395753",
            ]),
        ]),
        merchant(id: "vitaly", name: "Vitaly", domain: "vitalydesign.com", color: "#51565B", products: [
            product(4415294537803, "Herringbone Chain", "50.00", "glide", "Vitaly", [
                "https://cdn.shopify.com/s/files/1/0161/1184/files/HerringboneChain-Vitaly-SS-1.jpg?v=1753898142",
                "https://cdn.shopify.com/s/files/1/0161/1184/files/Herringbone_Chain-Vitaly-SS-2.jpg?v=1753898142",
                "https://cdn.shopify.com/s/files/1/0161/1184/files/Herringbone_Chain-Vitaly-OnFig-SS-1-model-stainless-steel.jpg?v=1753898051",
            ]),
            product(6796258934859, "Figaro Chain", "50.00", "figaro-chain", "Vitaly", [
                "https://cdn.shopify.com/s/files/1/0161/1184/files/FigaroChain-Vitaly-SS-1.jpg?v=1753889158",
                "https://cdn.shopify.com/s/files/1/0161/1184/files/Figaro_Chain-Vitaly-SS-2.jpg?v=1753889158",
            ]),
            product(6756794171467, "Rope Chain", "65.00", "rope-chain", "Vitaly", [
                "https://cdn.shopify.com/s/files/1/0161/1184/files/Rope_Chain-Vitaly-SS-1.jpg?v=1752609628",
                "https://cdn.shopify.com/s/files/1/0161/1184/files/RopeChain-Vitaly-SS-2_7621045c-cc13-4cef-aa8b-1af510f64979.jpg?v=1753905705",
            ]),
            product(6719450447947, "Rounded Box Chain", "50.00", "rounded-box-chain", "Vitaly", [
                "https://cdn.shopify.com/s/files/1/0161/1184/products/RoundedBoxChain2.0-Vitaly-SS-1.jpg?v=1706734387",
                "https://cdn.shopify.com/s/files/1/0161/1184/products/RoundedBoxChain2.0-Vitaly-SS-2.jpg?v=1706734387",
            ]),
        ]),
        merchant(id: "svrn-rick-owens", name: "SVRN — Rick Owens", domain: "svrn.com", color: "#252426", products: [
            product(15632596205641, "Rick Owens Oversized Level in Black", "690.00", "rick-owens-oversized-level-in-black-fw26-svrn", "Rick Owens", [
                "https://cdn.shopify.com/s/files/1/0019/0742/5331/files/oversized-level-in-black-men-s-t-shirts-rick-owens-svrn-chicago-1254116430.jpg?v=1786654058",
                "https://cdn.shopify.com/s/files/1/0019/0742/5331/files/oversized-level-in-black-men-s-t-shirts-rick-owens-svrn-chicago-1254116429.jpg?v=1786654048",
            ]),
            product(15632596861001, "Rick Owens Dietrich Drawstring in Black", "840.00", "rick-owens-dietrich-drawstring-in-black-fw26-svrn", "Rick Owens", [
                "https://cdn.shopify.com/s/files/1/0019/0742/5331/files/dietrich-drawstring-in-black-men-s-jeans-rick-owens-svrn-chicago-1254124475.jpg?v=1786660728",
                "https://cdn.shopify.com/s/files/1/0019/0742/5331/files/dietrich-drawstring-in-black-men-s-jeans-rick-owens-svrn-chicago-1254124474.jpg?v=1786660720",
            ]),
            product(15632596271177, "Rick Owens Jason Hoodie in Black", "1330.00", "rick-owens-jason-hoodie-in-black-fw26-svrn", "Rick Owens", [
                "https://cdn.shopify.com/s/files/1/0019/0742/5331/files/jason-hoodie-in-black-men-s-sweatshirts-rick-owens-svrn-chicago-1254116480.jpg?v=1786654007",
                "https://cdn.shopify.com/s/files/1/0019/0742/5331/files/jason-hoodie-in-black-men-s-sweatshirts-rick-owens-svrn-chicago-1254116479.jpg?v=1786653998",
            ]),
            product(15632596992073, "Rick Owens Gethshade Sunglasses in Blood Temple", "610.00", "rick-owens-gethshade-sunglasses-in-blood-temple-black-lens-fw26-svrn", "Rick Owens", [
                "https://cdn.shopify.com/s/files/1/0019/0742/5331/files/gethshade-sunglasses-in-blood-temple-black-lens-eyewear-rick-owens-os-svrn-chicago-1253522274.jpg?v=1786119806",
                "https://cdn.shopify.com/s/files/1/0019/0742/5331/files/gethshade-sunglasses-in-blood-temple-black-lens-eyewear-rick-owens-os-svrn-chicago-1253522272.jpg?v=1786119799",
            ]),
        ]),
        merchant(id: "matteau", name: "Matteau", domain: "matteau-store.com", color: "#5A423C", products: [
            product(9025373044958, "Petite Triangle Top – Deep Black", "160.00", "petite-triangle-top-a-b-cup-deep-black", "Matteau", [
                "https://cdn.shopify.com/s/files/1/0728/6728/3166/files/S35-PTRIT_BLACK_PETITETRIANGLETOP_PETIB_BLACK_PETITEBRIEF_MODEL-24679-Matteau-D4-0431_2ca1ff88-f50c-42ba-a294-6ed46318cd0c.jpg?v=1759518534",
                "https://cdn.shopify.com/s/files/1/0728/6728/3166/files/S35-PTRIT_BLACK_PETITETRIANGLETOP_PETIB_BLACK_PETITEBRIEF_MODEL-24679-Matteau-D4-0446_c1d80d60-09f6-4699-aab2-372a8c8c2503.jpg?v=1759518534",
            ]),
            product(9025359675614, "Balconette Top – Deep Black", "160.00", "balconette-top-a-b-cup-deep-black", "Matteau", [
                "https://cdn.shopify.com/s/files/1/0728/6728/3166/files/S25-BALCT_BLACK_BALCONETTETOP_HIWAB_BLACK_HIGHWAISTBRIEF_MODEL-24679-Matteau-D4-0174_3afea7de-cef3-4e27-b97f-e8714dfaf095.jpg?v=1761092324",
                "https://cdn.shopify.com/s/files/1/0728/6728/3166/files/S25-BALCT_BLACK_BALCONETTETOP_HIWAB_BLACK_HIGHWAISTBRIEF_MODEL-24679-Matteau-D4-0128_6f1c7c71-a008-435a-b04e-8bf691db9e0c.jpg?v=1761092324",
            ]),
            product(9015274733790, "Racer Back Maillot – Clay", "340.00", "racer-back-maillot-clay", "Matteau", [
                "https://cdn.shopify.com/s/files/1/0728/6728/3166/files/RACBM_CLAY_RACERBACKMAILLOT_MODELDay02_Tari10368.jpg?v=1773290626",
                "https://cdn.shopify.com/s/files/1/0728/6728/3166/files/RACBM_CLAY_RACERBACKMAILLOT_MODELDay02_Tari10374_1.jpg?v=1773290626",
            ]),
            product(9013492023518, "Square Maillot – Tomato Crinkle", "340.00", "square-maillot-tomato-crinkle", "Matteau", [
                "https://cdn.shopify.com/s/files/1/0728/6728/3166/files/SQURM_TOMATOCRINKLE_SQUAREMAILLOT_MODELDay02_Tari10286.jpg?v=1773291134",
                "https://cdn.shopify.com/s/files/1/0728/6728/3166/files/SQURM_TOMATOCRINKLE_SQUAREMAILLOT_MODELDay02_Tari10295.jpg?v=1773291221",
            ]),
        ]),
    ]

    private static func story(
        id: String,
        title: String,
        subtitle: String,
        keys: Set<String>,
        accent: String,
        products: [FeedStory.ProductReference]
    ) -> FeedStory {
        FeedStory(
            id: id,
            eyebrow: "",
            title: title,
            subtitle: subtitle,
            format: .world,
            topicKeys: keys,
            accentHex: accent,
            coverImageName: nil,
            destinationLabel: "Explore",
            products: products
        )
    }

    private static func ref(_ merchantID: String, _ productID: Int) -> FeedStory.ProductReference {
        .init(merchantID: merchantID, productID: productID)
    }

    private static func merchant(
        id: String,
        name: String,
        domain: String,
        color: String,
        products: [SampleMerchant.Product]
    ) -> SampleMerchant {
        SampleMerchant(
            id: id,
            name: name,
            description: "",
            rating: 4.8,
            totalRatings: 0,
            totalReviews: 0,
            primaryColor: Color(hex: color),
            secondaryColor: Color(hex: color),
            collections: [],
            products: products.map { item in
                SampleMerchant.Product(
                    id: item.id,
                    title: item.title,
                    price: item.price,
                    handle: item.handle,
                    productType: item.productType,
                    vendor: item.vendor,
                    imageURL: item.imageURL,
                    shopURL: "https://\(domain)/products/\(item.handle)",
                    tags: item.tags,
                    allImageURLs: item.allImageURLs,
                    currencyCode: item.currencyCode,
                    productDescription: item.productDescription,
                    videoUrl: item.videoUrl,
                    allVideoURLs: item.allVideoURLs
                )
            },
            featuredImageURLs: products.flatMap(\.allImageURLs),
            logoImageURL: nil,
            wordmarkImageURL: nil,
            coverImageURL: products.first?.allImageURLs.dropFirst().first ?? products.first?.imageURL,
            videoURL: nil,
            coverDominantColor: color,
            productCategory: nil,
            logoFitsInCircle: false
        )
    }

    private static func product(
        _ id: Int,
        _ title: String,
        _ price: String,
        _ handle: String,
        _ vendor: String,
        _ images: [String]
    ) -> SampleMerchant.Product {
        SampleMerchant.Product(
            id: id,
            title: title,
            price: price,
            handle: handle,
            productType: nil,
            vendor: vendor,
            imageURL: images.first,
            shopURL: nil,
            tags: ["canonical-catalog"],
            allImageURLs: images,
            currencyCode: "USD",
            productDescription: nil,
            videoUrl: nil,
            allVideoURLs: []
        )
    }
}
