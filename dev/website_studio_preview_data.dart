// GENERATED for the dev preview only (from the backend schema + website text).
// ignore_for_file: lines_longer_than_80_chars
const previewSchemaJson = r'''{
 "sections": {
  "hero": {
   "label": "Hero (top of home page)",
   "page": "home",
   "fields": {
    "title": {
     "type": "text",
     "label": "Title",
     "maxLength": 60
    },
    "subtitle": {
     "type": "textarea",
     "label": "Subtitle",
     "maxLength": 200
    },
    "ctaLabel": {
     "type": "text",
     "label": "Button text",
     "maxLength": 30
    },
    "imageDesktop": {
     "type": "image",
     "label": "Background (desktop)",
     "rule": "heroDesktop",
     "upload": {
      "key": "heroDesktop",
      "label": "Hero background (desktop)",
      "mimeTypes": [
       "image/jpeg",
       "image/png",
       "image/webp"
      ],
      "extensions": [
       ".jpg",
       ".jpeg",
       ".png",
       ".webp"
      ],
      "maxBytes": 5242880,
      "minWidth": 1600,
      "minHeight": 900,
      "ratio": [
       1.6,
       1.9
      ],
      "shape": "Landscape, about 16:9",
      "hint": "JPG, PNG, WebP · max 5 MB · at least 1600 × 900 px · Landscape, about 16:9"
     }
    },
    "imageMobile": {
     "type": "image",
     "label": "Background (mobile)",
     "rule": "heroMobile",
     "upload": {
      "key": "heroMobile",
      "label": "Hero background (mobile)",
      "mimeTypes": [
       "image/jpeg",
       "image/png",
       "image/webp"
      ],
      "extensions": [
       ".jpg",
       ".jpeg",
       ".png",
       ".webp"
      ],
      "maxBytes": 4194304,
      "minWidth": 1080,
      "minHeight": 1920,
      "ratio": [
       0.5,
       0.62
      ],
      "shape": "Portrait, about 9:16",
      "hint": "JPG, PNG, WebP · max 4 MB · at least 1080 × 1920 px · Portrait, about 9:16"
     }
    },
    "stats": {
     "type": "list",
     "label": "Counters",
     "maxItems": 3,
     "fields": {
      "value": {
       "type": "number",
       "label": "Number",
       "min": 0,
       "max": 1000000,
       "required": true
      },
      "suffix": {
       "type": "text",
       "label": "After number (e.g. +)",
       "maxLength": 3
      },
      "label": {
       "type": "text",
       "label": "Label",
       "maxLength": 30,
       "required": true
      }
     }
    }
   }
  },
  "availabilityStrip": {
   "label": "Open dates strip",
   "page": "home",
   "fields": {
    "eyebrow": {
     "type": "text",
     "label": "Small heading",
     "maxLength": 40
    },
    "title": {
     "type": "text",
     "label": "Heading",
     "maxLength": 40
    },
    "ctaLabel": {
     "type": "text",
     "label": "Button text",
     "maxLength": 30
    }
   }
  },
  "intro": {
   "label": "Introduction",
   "page": "home",
   "fields": {
    "eyebrow": {
     "type": "text",
     "label": "Small heading",
     "maxLength": 40
    },
    "title": {
     "type": "text",
     "label": "Heading",
     "maxLength": 80
    },
    "body": {
     "type": "textarea",
     "label": "Text",
     "maxLength": 400
    },
    "image": {
     "type": "image",
     "label": "Photo",
     "rule": "portrait",
     "upload": {
      "key": "portrait",
      "label": "Portrait photo",
      "mimeTypes": [
       "image/jpeg",
       "image/webp"
      ],
      "extensions": [
       ".jpg",
       ".jpeg",
       ".webp"
      ],
      "maxBytes": 3145728,
      "minWidth": 900,
      "minHeight": 1125,
      "ratio": [
       0.74,
       0.86
      ],
      "shape": "Portrait, 4:5",
      "hint": "JPG, WebP · max 3 MB · at least 900 × 1125 px · Portrait, 4:5"
     }
    },
    "highlights": {
     "type": "list",
     "label": "Highlights",
     "maxItems": 3,
     "fields": {
      "label": {
       "type": "text",
       "label": "Title",
       "maxLength": 30,
       "required": true
      },
      "text": {
       "type": "textarea",
       "label": "Text",
       "maxLength": 160,
       "required": true
      }
     }
    }
   }
  },
  "recentBrides": {
   "label": "Recent brides",
   "page": "home",
   "fields": {
    "eyebrow": {
     "type": "text",
     "label": "Small heading",
     "maxLength": 40
    },
    "title": {
     "type": "text",
     "label": "Heading",
     "maxLength": 80
    }
   }
  },
  "packagesPreview": {
   "label": "Packages preview",
   "page": "home",
   "fields": {
    "eyebrow": {
     "type": "text",
     "label": "Small heading",
     "maxLength": 40
    },
    "title": {
     "type": "text",
     "label": "Heading",
     "maxLength": 80
    }
   }
  },
  "about": {
   "label": "About Feeniya",
   "page": "home",
   "fields": {
    "eyebrow": {
     "type": "text",
     "label": "Small heading",
     "maxLength": 40
    },
    "title": {
     "type": "text",
     "label": "Heading",
     "maxLength": 80
    },
    "quote": {
     "type": "textarea",
     "label": "Quote",
     "maxLength": 200
    },
    "body": {
     "type": "textarea",
     "label": "Text",
     "maxLength": 800
    },
    "portrait": {
     "type": "image",
     "label": "Portrait",
     "rule": "portrait",
     "upload": {
      "key": "portrait",
      "label": "Portrait photo",
      "mimeTypes": [
       "image/jpeg",
       "image/webp"
      ],
      "extensions": [
       ".jpg",
       ".jpeg",
       ".webp"
      ],
      "maxBytes": 3145728,
      "minWidth": 900,
      "minHeight": 1125,
      "ratio": [
       0.74,
       0.86
      ],
      "shape": "Portrait, 4:5",
      "hint": "JPG, WebP · max 3 MB · at least 900 × 1125 px · Portrait, 4:5"
     }
    },
    "stats": {
     "type": "list",
     "label": "Facts",
     "maxItems": 3,
     "fields": {
      "number": {
       "type": "text",
       "label": "Number / word",
       "maxLength": 12,
       "required": true
      },
      "label": {
       "type": "text",
       "label": "Label",
       "maxLength": 30,
       "required": true
      }
     }
    }
   }
  },
  "howItWorks": {
   "label": "How it works",
   "page": "home",
   "fields": {
    "eyebrow": {
     "type": "text",
     "label": "Small heading",
     "maxLength": 40
    },
    "title": {
     "type": "text",
     "label": "Heading",
     "maxLength": 80
    },
    "steps": {
     "type": "list",
     "label": "Steps",
     "maxItems": 6,
     "fields": {
      "title": {
       "type": "text",
       "label": "Step title",
       "maxLength": 40,
       "required": true
      },
      "text": {
       "type": "textarea",
       "label": "Step text",
       "maxLength": 200,
       "required": true
      }
     }
    }
   }
  },
  "faq": {
   "label": "FAQ",
   "page": "home",
   "fields": {
    "eyebrow": {
     "type": "text",
     "label": "Small heading",
     "maxLength": 40
    },
    "title": {
     "type": "text",
     "label": "Heading",
     "maxLength": 80
    },
    "items": {
     "type": "list",
     "label": "Questions",
     "maxItems": 20,
     "fields": {
      "question": {
       "type": "text",
       "label": "Question",
       "maxLength": 120,
       "required": true
      },
      "answer": {
       "type": "textarea",
       "label": "Answer",
       "maxLength": 600,
       "required": true
      }
     }
    }
   }
  },
  "packagesPage": {
   "label": "Packages page",
   "page": "packages",
   "fields": {
    "title": {
     "type": "text",
     "label": "Heading",
     "maxLength": 80
    },
    "intro": {
     "type": "textarea",
     "label": "Intro text",
     "maxLength": 300
    },
    "comparison": {
     "type": "list",
     "label": "Comparison table rows",
     "maxItems": 12,
     "fields": {
      "feature": {
       "type": "text",
       "label": "Feature",
       "maxLength": 60,
       "required": true
      },
      "values": {
       "type": "keyedText",
       "label": "Value per package",
       "maxLength": 80
      }
     }
    },
    "guarantees": {
     "type": "list",
     "label": "Why brides trust us",
     "maxItems": 6,
     "fields": {
      "title": {
       "type": "text",
       "label": "Title",
       "maxLength": 40,
       "required": true
      },
      "text": {
       "type": "textarea",
       "label": "Text",
       "maxLength": 200,
       "required": true
      }
     }
    }
   }
  },
  "policies": {
   "label": "Policies",
   "page": "policies",
   "fields": {
    "title": {
     "type": "text",
     "label": "Heading",
     "maxLength": 80
    },
    "lastUpdated": {
     "type": "text",
     "label": "Last updated (e.g. 16 Nov 2026)",
     "maxLength": 30
    },
    "sections": {
     "type": "list",
     "label": "Policy sections",
     "maxItems": 20,
     "fields": {
      "heading": {
       "type": "text",
       "label": "Heading",
       "maxLength": 80,
       "required": true
      },
      "body": {
       "type": "textarea",
       "label": "Text",
       "maxLength": 3000,
       "required": true
      }
     }
    }
   }
  },
  "contact": {
   "label": "Contact & Footer",
   "page": "global",
   "fields": {
    "phone": {
     "type": "phone",
     "label": "Phone"
    },
    "whatsapp": {
     "type": "phone",
     "label": "WhatsApp number"
    },
    "email": {
     "type": "email",
     "label": "Email"
    },
    "address": {
     "type": "textarea",
     "label": "Studio address",
     "maxLength": 300
    },
    "mapUrl": {
     "type": "url",
     "label": "Google Maps link",
     "maxLength": 500
    },
    "hours": {
     "type": "text",
     "label": "Opening hours",
     "maxLength": 100
    },
    "instagramUrl": {
     "type": "url",
     "label": "Instagram",
     "maxLength": 200
    },
    "facebookUrl": {
     "type": "url",
     "label": "Facebook",
     "maxLength": 200
    },
    "youtubeUrl": {
     "type": "url",
     "label": "YouTube",
     "maxLength": 200
    },
    "logo": {
     "type": "image",
     "label": "Logo",
     "rule": "logo",
     "upload": {
      "key": "logo",
      "label": "Logo",
      "mimeTypes": [
       "image/png",
       "image/webp"
      ],
      "extensions": [
       ".png",
       ".webp"
      ],
      "maxBytes": 1048576,
      "minWidth": 300,
      "minHeight": 100,
      "ratio": null,
      "shape": "Transparent background",
      "hint": "PNG, WebP · max 1 MB · at least 300 × 100 px · Transparent background"
     }
    },
    "logoWhite": {
     "type": "image",
     "label": "Logo (white, for dark backgrounds)",
     "rule": "logo",
     "upload": {
      "key": "logo",
      "label": "Logo",
      "mimeTypes": [
       "image/png",
       "image/webp"
      ],
      "extensions": [
       ".png",
       ".webp"
      ],
      "maxBytes": 1048576,
      "minWidth": 300,
      "minHeight": 100,
      "ratio": null,
      "shape": "Transparent background",
      "hint": "PNG, WebP · max 1 MB · at least 300 × 100 px · Transparent background"
     }
    }
   }
  },
  "seo": {
   "label": "SEO & sharing",
   "page": "global",
   "fields": {
    "siteTitle": {
     "type": "text",
     "label": "Browser tab / Google title",
     "maxLength": 70
    },
    "siteDescription": {
     "type": "textarea",
     "label": "Google description",
     "maxLength": 160
    },
    "shareImage": {
     "type": "image",
     "label": "Image shown when the link is shared",
     "rule": "shareImage",
     "upload": {
      "key": "shareImage",
      "label": "Social share image",
      "mimeTypes": [
       "image/jpeg",
       "image/png"
      ],
      "extensions": [
       ".jpg",
       ".jpeg",
       ".png"
      ],
      "maxBytes": 2097152,
      "minWidth": 1200,
      "minHeight": 630,
      "ratio": [
       1.85,
       1.97
      ],
      "shape": "Landscape, 1.91:1 (1200 × 630)",
      "hint": "JPG, PNG · max 2 MB · at least 1200 × 630 px · Landscape, 1.91:1 (1200 × 630)"
     }
    },
    "favicon": {
     "type": "image",
     "label": "Favicon",
     "rule": "favicon",
     "upload": {
      "key": "favicon",
      "label": "Favicon",
      "mimeTypes": [
       "image/png"
      ],
      "extensions": [
       ".png"
      ],
      "maxBytes": 204800,
      "minWidth": 512,
      "minHeight": 512,
      "ratio": [
       1,
       1
      ],
      "shape": "Square",
      "hint": "PNG · max 200 KB · at least 512 × 512 px · Square"
     }
    }
   }
  }
 },
 "gallery": {
  "categories": [
   {
    "key": "makeup",
    "label": "Bridal Makeup"
   },
   {
    "key": "hair",
    "label": "Hairstyling"
   },
   {
    "key": "styling",
    "label": "Styling"
   },
   {
    "key": "events",
    "label": "Reception & Events"
   }
  ],
  "upload": {
   "key": "gallery",
   "label": "Portfolio / gallery photo",
   "mimeTypes": [
    "image/jpeg",
    "image/webp"
   ],
   "extensions": [
    ".jpg",
    ".jpeg",
    ".webp"
   ],
   "maxBytes": 4194304,
   "minWidth": 800,
   "minHeight": 1200,
   "ratio": [
    0.6,
    0.85
   ],
   "shape": "Portrait, 4:5 or 2:3",
   "hint": "JPG, WebP · max 4 MB · at least 800 × 1200 px · Portrait, 4:5 or 2:3"
  }
 },
 "packageFields": {
  "show": {
   "type": "boolean",
   "label": "Show on website"
  },
  "sortOrder": {
   "type": "number",
   "label": "Order on website",
   "min": 0,
   "max": 999
  },
  "tagline": {
   "type": "text",
   "label": "Tagline",
   "maxLength": 100
  },
  "description": {
   "type": "textarea",
   "label": "Website description",
   "maxLength": 400
  },
  "idealFor": {
   "type": "textarea",
   "label": "Ideal for",
   "maxLength": 200
  },
  "features": {
   "type": "textList",
   "label": "What's included",
   "maxItems": 12,
   "maxLength": 120
  },
  "durationLabel": {
   "type": "text",
   "label": "Duration (e.g. 4 hours)",
   "maxLength": 30
  },
  "highlighted": {
   "type": "boolean",
   "label": "Mark as most popular"
  },
  "priceFrom": {
   "type": "boolean",
   "label": "Show price as \"from\""
  },
  "coverImage": {
   "type": "image",
   "label": "Cover image",
   "rule": "packageCover",
   "upload": {
    "key": "packageCover",
    "label": "Package cover",
    "mimeTypes": [
     "image/jpeg",
     "image/webp"
    ],
    "extensions": [
     ".jpg",
     ".jpeg",
     ".webp"
    ],
    "maxBytes": 3145728,
    "minWidth": 1200,
    "minHeight": 900,
    "ratio": [
     1.25,
     1.42
    ],
    "shape": "Landscape, 4:3",
    "hint": "JPG, WebP · max 3 MB · at least 1200 × 900 px · Landscape, 4:3"
   }
  }
 },
 "addonFields": {
  "show": {
   "type": "boolean",
   "label": "Show on website"
  },
  "sortOrder": {
   "type": "number",
   "label": "Order on website",
   "min": 0,
   "max": 999
  },
  "description": {
   "type": "textarea",
   "label": "Website description",
   "maxLength": 200
  }
 }
}''';
const previewDefaultsJson = r'''{"hero":{"title":"Bridal beauty, defined.","subtitle":"Luxury bridal makeup and hairstyling by Feeniya Nizan, for brides in Kerala and across the world.","ctaLabel":"","stats":[{"value":1000,"suffix":"+","label":"brides styled"},{"value":10,"suffix":"+","label":"years of expertise"}]},"availabilityStrip":{"eyebrow":"Open dates","title":"Book your slot","ctaLabel":"View full calendar"},"intro":{"eyebrow":"The experience","title":"For brides who want more.","body":"Signature bridal looks, personalised styling, and a calm, thoughtful experience from trial to the big day.","highlights":[{"label":"Personalised","text":"Every look is built around you — your face, your style, your story."},{"label":"Calm & unhurried","text":"We pace every session so you feel relaxed and radiant."},{"label":"Trial to big day","text":"Full support from your trial session through the wedding morning."}]},"recentBrides":{"eyebrow":"Portfolio","title":"Recent brides"},"packagesPreview":{"eyebrow":"Services","title":"Our packages"},"about":{"eyebrow":"About Feeniya","title":"The artist behind Team N","quote":"My approach has always been simple — to bring out the most confident, beautiful version of every bride.","body":"Founder and lead artist at Team N Makeovers, Feeniya Nizan brings over a decade of experience in bridal makeup and hairstyling, creating timeless looks for brides in Kerala and around the world.","stats":[{"number":"1000+","label":"Brides styled"},{"number":"10+","label":"Years of expertise"},{"number":"Kerala","label":"& worldwide"}]},"howItWorks":{"eyebrow":"The process","title":"How booking works","steps":[{"title":"Choose package","text":"Browse our Airbrush, Platinum, or Custom packages and pick the one that fits your vision."},{"title":"Pick a date","text":"Check the live calendar and select an available slot that works for your schedule."},{"title":"Pay advance","text":"Secure your date with a small advance — the rest is settled on the day."},{"title":"Get confirmation","text":"Receive your booking reference and all details instantly via WhatsApp and email."}]},"faq":{"eyebrow":"FAQs","title":"Frequently asked questions","items":[{"question":"How do I book a slot?","answer":"Choose a package, pick an available date and slot on the calendar, enter your details and pay a small advance online. You receive a booking reference straight away."},{"question":"Is a trial session included?","answer":"A trial is included with the Platinum package. For Airbrush and Custom you can add one as an extra while booking."},{"question":"Can I book for a destination wedding?","answer":"Yes. Choose the Custom package and tell us the venue and dates. Travel and stay for the team are agreed with you before the booking is confirmed."},{"question":"What is your cancellation policy?","answer":"You can reschedule or cancel from the Manage booking page using your booking reference and phone number. The refund depends on how far ahead you cancel; the full terms are on the Policies page."}]},"packagesPage":{"title":"Bridal Packages & Styling","intro":"Tailored makeup, hair design, and couture styling crafted by Feeniya Nizan and Team N. Every package is thoughtfully paced to make you feel radiant, serene, and confident.","comparison":[{"feature":"Lead Artist","values":{}},{"feature":"Skin Prep & Makeup Base","values":{}},{"feature":"Hair Styling & Design","values":{}},{"feature":"Lashes & Eye Artistry","values":{}},{"feature":"Saree & Veil Placement","values":{}},{"feature":"Trial Session","values":{}},{"feature":"Touch-up Kit","values":{}},{"feature":"Travel Coverage","values":{}}],"guarantees":[{"title":"100% Luxury Products","text":"Exclusively using Charlotte Tilbury, Dior, NARS, MAC, and Huda Beauty for seamless, non-cakey perfection."},{"title":"Hospital-Grade Hygiene","text":"Strict brush sanitization, disposable applicators, and UV sterilization for immaculate safety."},{"title":"Calm & Punctual Pacing","text":"We buffer every bridal morning with generous margins so you are calm, unhurried, and on time."},{"title":"Camera & Flash Calibrated","text":"Crafted specifically to look effortlessly natural in person while translating flawlessly under studio flashes and 4K cameras."}]},"policies":{"title":"Studio Policies & Guidelines","lastUpdated":"","sections":[{"heading":"Booking & Advance Deposit","body":"A 25% non-refundable advance is required to lock and guarantee date exclusivity on our calendar.\nSlots are allotted strictly on a first-come, first-served basis upon advance receipt.\nThe remaining balance is payable on the wedding day prior to the artist's departure."},{"heading":"Punctuality & Wedding Morning Timeline","body":"We prepare a customized time buffer for your bridal look (usually 3.5 to 4.5 hours depending on the package).\nThe bride is requested to have clean, washed, and completely dried hair without heavy oils before the artist arrives.\nTimely start ensures stress-free photography and calm transitions to the ceremony stage."},{"heading":"Rescheduling & Date Changes","body":"Rescheduling is accommodated subject to artist availability on the new date.\nRequests made at least 30 days prior to the original wedding date incur zero rescheduling fees.\nIn the unforeseen event of government restrictions or force majeure, advances can be rolled forward up to 12 months."},{"heading":"Travel & Destination Weddings","body":"Travel within Kozhikode city limits is included in all standard bridal packages.\nFor outstation bookings across Kerala, Pan-India, or abroad, round-trip transport and safe stay for Feeniya Nizan & assistant are arranged by the client or billed transparently at actuals.\nEarly morning muhurthams (before 6:00 AM) may require the team to stay in close proximity the night before."},{"heading":"Hygiene & Skin Safety","body":"All brushes, beauty blenders, and tool kits undergo thorough hospital-grade sanitization between every client.\nDisposable mascara wands and lip applicators are utilized at all times.\nPlease alert our team during the pre-wedding consultation regarding any skin sensitivities or allergies."}]},"contact":{"phone":"+91 96454 24281","whatsapp":"919645424281","email":"inquiry@teamnmakeovers.com","address":"Kozhikode (Calicut), Kerala, India","mapUrl":"","hours":"Mon – Sun: 9:00 AM – 7:00 PM IST","instagramUrl":"https://instagram.com/teamnmakeovers","facebookUrl":"","youtubeUrl":""},"seo":{"siteTitle":"Team N | Luxury South Asian Bridal Experience","siteDescription":"Luxury bridal makeup and hairstyling by Feeniya Nizan in Kozhikode, Kerala — for brides across Kerala and destination weddings worldwide."}}''';
