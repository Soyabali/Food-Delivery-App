-- =====================================================================
-- Apna Food - PostgreSQL schema (generated, do not edit by hand)
--
-- Source of truth: SQLAlchemy models in backend/app/models and Alembic
-- migrations in backend/alembic/versions. Regenerate with
-- scripts/export_schema.py (see its docstring).
--
-- Normal setup uses Alembic (`alembic upgrade head`). Use this file to read
-- the schema or to create it manually in pgAdmin / psql.
-- =====================================================================

--
-- PostgreSQL database dump
--

--
-- Name: discount_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.discount_type AS ENUM (
    'percent',
    'flat'
);

--
-- Name: notification_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.notification_kind AS ENUM (
    'offer',
    'delivery',
    'info'
);

--
-- Name: order_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.order_status AS ENUM (
    'placed',
    'preparing',
    'out_for_delivery',
    'delivered',
    'cancelled'
);

--
-- Name: payment_method; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.payment_method AS ENUM (
    'upi',
    'card',
    'cod'
);

--
-- Name: payment_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.payment_status AS ENUM (
    'pending',
    'paid',
    'failed',
    'refunded'
);

--
-- Name: user_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.user_role AS ENUM (
    'customer',
    'admin'
);

--
-- Name: add_ons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.add_ons (
    id bigint NOT NULL,
    restaurant_id bigint NOT NULL,
    name character varying(80) NOT NULL,
    subtitle character varying(150),
    price numeric(10,2) NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_add_ons_price_positive CHECK ((price >= (0)::numeric))
);

--
-- Name: add_ons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.add_ons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: add_ons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.add_ons_id_seq OWNED BY public.add_ons.id;

--
-- Name: addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.addresses (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    label character varying(40) NOT NULL,
    line character varying(300) NOT NULL,
    icon character varying(20) DEFAULT 'home'::character varying NOT NULL,
    latitude numeric(9,6),
    longitude numeric(9,6),
    is_default boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_addresses_latitude_range CHECK (((latitude >= ('-90'::integer)::numeric) AND (latitude <= (90)::numeric))),
    CONSTRAINT ck_addresses_longitude_range CHECK (((longitude >= ('-180'::integer)::numeric) AND (longitude <= (180)::numeric)))
);

--
-- Name: addresses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.addresses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: addresses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.addresses_id_seq OWNED BY public.addresses.id;

--
-- Name: cart_item_add_ons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cart_item_add_ons (
    cart_item_id bigint NOT NULL,
    add_on_id bigint NOT NULL
);

--
-- Name: cart_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cart_items (
    id bigint NOT NULL,
    cart_id bigint NOT NULL,
    menu_item_id bigint NOT NULL,
    variant_id bigint,
    spice_level character varying(20),
    quantity smallint NOT NULL,
    note character varying(120),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_cart_items_quantity_range CHECK (((quantity >= 1) AND (quantity <= 20)))
);

--
-- Name: cart_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cart_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: cart_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cart_items_id_seq OWNED BY public.cart_items.id;

--
-- Name: carts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.carts (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    restaurant_id bigint,
    offer_id integer,
    instructions character varying(150) DEFAULT ''::character varying NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: carts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.carts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: carts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.carts_id_seq OWNED BY public.carts.id;

--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id integer NOT NULL,
    name character varying(60) NOT NULL,
    slug character varying(60) NOT NULL,
    emoji character varying(16),
    image_url character varying(500),
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.categories_id_seq OWNED BY public.categories.id;

--
-- Name: favorite_menu_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.favorite_menu_items (
    user_id bigint NOT NULL,
    menu_item_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: favorite_restaurants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.favorite_restaurants (
    user_id bigint NOT NULL,
    restaurant_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: media_assets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.media_assets (
    id bigint NOT NULL,
    file_name character varying(100) NOT NULL,
    original_name character varying(255) NOT NULL,
    content_type character varying(50) NOT NULL,
    size_bytes integer NOT NULL,
    url character varying(500) NOT NULL,
    uploaded_by_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_media_assets_size_positive CHECK ((size_bytes > 0))
);

--
-- Name: media_assets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.media_assets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: media_assets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.media_assets_id_seq OWNED BY public.media_assets.id;

--
-- Name: menu_item_variants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.menu_item_variants (
    id bigint NOT NULL,
    menu_item_id bigint NOT NULL,
    name character varying(60) NOT NULL,
    subtitle character varying(150),
    price_delta numeric(10,2) DEFAULT '0'::numeric NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    CONSTRAINT ck_menu_item_variants_price_delta_positive CHECK ((price_delta >= (0)::numeric))
);

--
-- Name: menu_item_variants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.menu_item_variants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: menu_item_variants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.menu_item_variants_id_seq OWNED BY public.menu_item_variants.id;

--
-- Name: menu_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.menu_items (
    id bigint NOT NULL,
    restaurant_id bigint NOT NULL,
    category_id integer,
    name character varying(150) NOT NULL,
    description text,
    price numeric(10,2) NOT NULL,
    image_url character varying(500),
    is_veg boolean DEFAULT false NOT NULL,
    is_available boolean DEFAULT true NOT NULL,
    has_spice_levels boolean DEFAULT false NOT NULL,
    allows_add_ons boolean DEFAULT true NOT NULL,
    cuisine character varying(40),
    tags character varying(40)[] DEFAULT '{}'::character varying[] NOT NULL,
    meal_types character varying(20)[] DEFAULT '{}'::character varying[] NOT NULL,
    ingredients character varying(120)[] DEFAULT '{}'::character varying[] NOT NULL,
    prep_time_minutes smallint,
    calories integer,
    difficulty character varying(20),
    servings smallint,
    rating numeric(2,1) DEFAULT '0'::numeric NOT NULL,
    rating_count integer DEFAULT 0 NOT NULL,
    badge character varying(30),
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_menu_items_calories_positive CHECK (((calories IS NULL) OR (calories >= 0))),
    CONSTRAINT ck_menu_items_price_positive CHECK ((price > (0)::numeric)),
    CONSTRAINT ck_menu_items_rating_range CHECK (((rating >= (0)::numeric) AND (rating <= (5)::numeric)))
);

--
-- Name: menu_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.menu_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: menu_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.menu_items_id_seq OWNED BY public.menu_items.id;

--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id bigint NOT NULL,
    user_id bigint,
    title character varying(120) NOT NULL,
    body character varying(500) NOT NULL,
    kind public.notification_kind DEFAULT 'info'::public.notification_kind NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    read_at timestamp with time zone
);

--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;

--
-- Name: offers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.offers (
    id integer NOT NULL,
    code character varying(30) NOT NULL,
    title character varying(80) NOT NULL,
    subtitle character varying(150) NOT NULL,
    description text,
    discount_type public.discount_type NOT NULL,
    value numeric(10,2) NOT NULL,
    max_discount numeric(10,2),
    min_order numeric(10,2) DEFAULT '0'::numeric NOT NULL,
    valid_for_first_n_orders integer,
    image_url character varying(500),
    is_featured boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    starts_at timestamp with time zone,
    ends_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_offers_date_range CHECK (((ends_at IS NULL) OR (starts_at IS NULL) OR (ends_at > starts_at))),
    CONSTRAINT ck_offers_min_order_positive CHECK ((min_order >= (0)::numeric)),
    CONSTRAINT ck_offers_percent_max_100 CHECK (((discount_type <> 'percent'::public.discount_type) OR (value <= (100)::numeric))),
    CONSTRAINT ck_offers_value_positive CHECK ((value > (0)::numeric))
);

--
-- Name: offers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.offers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: offers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.offers_id_seq OWNED BY public.offers.id;

--
-- Name: order_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_items (
    id bigint NOT NULL,
    order_id bigint NOT NULL,
    menu_item_id bigint,
    name character varying(150) NOT NULL,
    image_url character varying(500),
    is_veg boolean NOT NULL,
    variant_name character varying(60),
    spice_level character varying(20),
    add_on_names character varying(80)[] DEFAULT '{}'::character varying[] NOT NULL,
    note character varying(120),
    unit_price numeric(10,2) NOT NULL,
    quantity smallint NOT NULL,
    line_total numeric(10,2) NOT NULL,
    CONSTRAINT ck_order_items_amounts_positive CHECK (((unit_price >= (0)::numeric) AND (line_total >= (0)::numeric))),
    CONSTRAINT ck_order_items_quantity_range CHECK (((quantity >= 1) AND (quantity <= 20)))
);

--
-- Name: order_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.order_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: order_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.order_items_id_seq OWNED BY public.order_items.id;

--
-- Name: order_status_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_status_history (
    id bigint NOT NULL,
    order_id bigint NOT NULL,
    status public.order_status NOT NULL,
    changed_by_user_id bigint,
    note character varying(200),
    changed_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: order_status_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.order_status_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: order_status_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.order_status_history_id_seq OWNED BY public.order_status_history.id;

--
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orders (
    id bigint NOT NULL,
    order_number character varying(20) NOT NULL,
    user_id bigint NOT NULL,
    restaurant_id bigint NOT NULL,
    status public.order_status DEFAULT 'placed'::public.order_status NOT NULL,
    payment_method public.payment_method NOT NULL,
    payment_status public.payment_status DEFAULT 'pending'::public.payment_status NOT NULL,
    address_label character varying(40) NOT NULL,
    address_line character varying(300) NOT NULL,
    address_latitude numeric(9,6),
    address_longitude numeric(9,6),
    item_total numeric(10,2) NOT NULL,
    delivery_fee numeric(10,2) NOT NULL,
    taxes numeric(10,2) NOT NULL,
    discount numeric(10,2) DEFAULT '0'::numeric NOT NULL,
    total numeric(10,2) NOT NULL,
    offer_id integer,
    coupon_code character varying(30),
    instructions character varying(150),
    placed_at timestamp with time zone DEFAULT now() NOT NULL,
    eta timestamp with time zone NOT NULL,
    delivered_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_orders_amounts_positive CHECK (((item_total >= (0)::numeric) AND (delivery_fee >= (0)::numeric) AND (taxes >= (0)::numeric))),
    CONSTRAINT ck_orders_totals_positive CHECK (((discount >= (0)::numeric) AND (total >= (0)::numeric)))
);

--
-- Name: orders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.orders_id_seq OWNED BY public.orders.id;

--
-- Name: password_reset_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.password_reset_tokens (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    token_hash character varying(64) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    used_at timestamp with time zone,
    attempts smallint DEFAULT '0'::smallint NOT NULL
);

--
-- Name: password_reset_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.password_reset_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: password_reset_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.password_reset_tokens_id_seq OWNED BY public.password_reset_tokens.id;

--
-- Name: restaurants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.restaurants (
    id bigint NOT NULL,
    slug character varying(80) NOT NULL,
    name character varying(120) NOT NULL,
    description text,
    cuisines character varying(40)[] DEFAULT '{}'::character varying[] NOT NULL,
    image_url character varying(500),
    address_line character varying(300),
    latitude numeric(9,6) NOT NULL,
    longitude numeric(9,6) NOT NULL,
    rating numeric(2,1) DEFAULT '0'::numeric NOT NULL,
    rating_count integer DEFAULT 0 NOT NULL,
    delivery_time_min smallint NOT NULL,
    delivery_time_max smallint NOT NULL,
    cost_for_one integer NOT NULL,
    delivery_fee integer DEFAULT 0 NOT NULL,
    is_pure_veg boolean DEFAULT false NOT NULL,
    has_spice_levels boolean DEFAULT false NOT NULL,
    badge character varying(30),
    is_popular boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_restaurants_cost_for_one_positive CHECK ((cost_for_one >= 0)),
    CONSTRAINT ck_restaurants_delivery_fee_positive CHECK ((delivery_fee >= 0)),
    CONSTRAINT ck_restaurants_delivery_time CHECK (((delivery_time_min > 0) AND (delivery_time_max >= delivery_time_min))),
    CONSTRAINT ck_restaurants_latitude_range CHECK (((latitude >= ('-90'::integer)::numeric) AND (latitude <= (90)::numeric))),
    CONSTRAINT ck_restaurants_longitude_range CHECK (((longitude >= ('-180'::integer)::numeric) AND (longitude <= (180)::numeric))),
    CONSTRAINT ck_restaurants_rating_range CHECK (((rating >= (0)::numeric) AND (rating <= (5)::numeric)))
);

--
-- Name: restaurants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.restaurants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: restaurants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.restaurants_id_seq OWNED BY public.restaurants.id;

--
-- Name: user_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_sessions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    token_hash character varying(64) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    revoked_at timestamp with time zone,
    user_agent character varying(255)
);

--
-- Name: user_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: user_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_sessions_id_seq OWNED BY public.user_sessions.id;

--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    full_name character varying(120) NOT NULL,
    email character varying(254) NOT NULL,
    phone character varying(20),
    password_hash character varying(255) NOT NULL,
    role public.user_role DEFAULT 'customer'::public.user_role NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    selected_address_id bigint,
    last_login_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;

--
-- Name: add_ons id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.add_ons ALTER COLUMN id SET DEFAULT nextval('public.add_ons_id_seq'::regclass);

--
-- Name: addresses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses ALTER COLUMN id SET DEFAULT nextval('public.addresses_id_seq'::regclass);

--
-- Name: cart_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cart_items ALTER COLUMN id SET DEFAULT nextval('public.cart_items_id_seq'::regclass);

--
-- Name: carts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carts ALTER COLUMN id SET DEFAULT nextval('public.carts_id_seq'::regclass);

--
-- Name: categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval('public.categories_id_seq'::regclass);

--
-- Name: media_assets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_assets ALTER COLUMN id SET DEFAULT nextval('public.media_assets_id_seq'::regclass);

--
-- Name: menu_item_variants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_item_variants ALTER COLUMN id SET DEFAULT nextval('public.menu_item_variants_id_seq'::regclass);

--
-- Name: menu_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_items ALTER COLUMN id SET DEFAULT nextval('public.menu_items_id_seq'::regclass);

--
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);

--
-- Name: offers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offers ALTER COLUMN id SET DEFAULT nextval('public.offers_id_seq'::regclass);

--
-- Name: order_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items ALTER COLUMN id SET DEFAULT nextval('public.order_items_id_seq'::regclass);

--
-- Name: order_status_history id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_status_history ALTER COLUMN id SET DEFAULT nextval('public.order_status_history_id_seq'::regclass);

--
-- Name: orders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders ALTER COLUMN id SET DEFAULT nextval('public.orders_id_seq'::regclass);

--
-- Name: password_reset_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_reset_tokens ALTER COLUMN id SET DEFAULT nextval('public.password_reset_tokens_id_seq'::regclass);

--
-- Name: restaurants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.restaurants ALTER COLUMN id SET DEFAULT nextval('public.restaurants_id_seq'::regclass);

--
-- Name: user_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_sessions ALTER COLUMN id SET DEFAULT nextval('public.user_sessions_id_seq'::regclass);

--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);

--
-- Name: add_ons pk_add_ons; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.add_ons
    ADD CONSTRAINT pk_add_ons PRIMARY KEY (id);

--
-- Name: addresses pk_addresses; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT pk_addresses PRIMARY KEY (id);

--
-- Name: cart_item_add_ons pk_cart_item_add_ons; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cart_item_add_ons
    ADD CONSTRAINT pk_cart_item_add_ons PRIMARY KEY (cart_item_id, add_on_id);

--
-- Name: cart_items pk_cart_items; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cart_items
    ADD CONSTRAINT pk_cart_items PRIMARY KEY (id);

--
-- Name: carts pk_carts; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carts
    ADD CONSTRAINT pk_carts PRIMARY KEY (id);

--
-- Name: categories pk_categories; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT pk_categories PRIMARY KEY (id);

--
-- Name: favorite_menu_items pk_favorite_menu_items; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorite_menu_items
    ADD CONSTRAINT pk_favorite_menu_items PRIMARY KEY (user_id, menu_item_id);

--
-- Name: favorite_restaurants pk_favorite_restaurants; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorite_restaurants
    ADD CONSTRAINT pk_favorite_restaurants PRIMARY KEY (user_id, restaurant_id);

--
-- Name: media_assets pk_media_assets; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_assets
    ADD CONSTRAINT pk_media_assets PRIMARY KEY (id);

--
-- Name: menu_item_variants pk_menu_item_variants; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_item_variants
    ADD CONSTRAINT pk_menu_item_variants PRIMARY KEY (id);

--
-- Name: menu_items pk_menu_items; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_items
    ADD CONSTRAINT pk_menu_items PRIMARY KEY (id);

--
-- Name: notifications pk_notifications; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT pk_notifications PRIMARY KEY (id);

--
-- Name: offers pk_offers; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offers
    ADD CONSTRAINT pk_offers PRIMARY KEY (id);

--
-- Name: order_items pk_order_items; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT pk_order_items PRIMARY KEY (id);

--
-- Name: order_status_history pk_order_status_history; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_status_history
    ADD CONSTRAINT pk_order_status_history PRIMARY KEY (id);

--
-- Name: orders pk_orders; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT pk_orders PRIMARY KEY (id);

--
-- Name: password_reset_tokens pk_password_reset_tokens; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_reset_tokens
    ADD CONSTRAINT pk_password_reset_tokens PRIMARY KEY (id);

--
-- Name: restaurants pk_restaurants; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.restaurants
    ADD CONSTRAINT pk_restaurants PRIMARY KEY (id);

--
-- Name: user_sessions pk_user_sessions; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT pk_user_sessions PRIMARY KEY (id);

--
-- Name: users pk_users; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT pk_users PRIMARY KEY (id);

--
-- Name: carts uq_carts_user_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carts
    ADD CONSTRAINT uq_carts_user_id UNIQUE (user_id);

--
-- Name: categories uq_categories_name; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT uq_categories_name UNIQUE (name);

--
-- Name: categories uq_categories_slug; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT uq_categories_slug UNIQUE (slug);

--
-- Name: media_assets uq_media_assets_file_name; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_assets
    ADD CONSTRAINT uq_media_assets_file_name UNIQUE (file_name);

--
-- Name: media_assets uq_media_assets_url; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_assets
    ADD CONSTRAINT uq_media_assets_url UNIQUE (url);

--
-- Name: offers uq_offers_code; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offers
    ADD CONSTRAINT uq_offers_code UNIQUE (code);

--
-- Name: orders uq_orders_order_number; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT uq_orders_order_number UNIQUE (order_number);

--
-- Name: password_reset_tokens uq_password_reset_tokens_token_hash; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_reset_tokens
    ADD CONSTRAINT uq_password_reset_tokens_token_hash UNIQUE (token_hash);

--
-- Name: restaurants uq_restaurants_slug; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.restaurants
    ADD CONSTRAINT uq_restaurants_slug UNIQUE (slug);

--
-- Name: user_sessions uq_user_sessions_token_hash; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT uq_user_sessions_token_hash UNIQUE (token_hash);

--
-- Name: ix_add_ons_restaurant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_add_ons_restaurant_id ON public.add_ons USING btree (restaurant_id);

--
-- Name: ix_addresses_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_addresses_user_id ON public.addresses USING btree (user_id);

--
-- Name: ix_cart_items_cart_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_cart_items_cart_id ON public.cart_items USING btree (cart_id);

--
-- Name: ix_favorite_menu_items_menu_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_favorite_menu_items_menu_item_id ON public.favorite_menu_items USING btree (menu_item_id);

--
-- Name: ix_favorite_restaurants_restaurant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_favorite_restaurants_restaurant_id ON public.favorite_restaurants USING btree (restaurant_id);

--
-- Name: ix_menu_item_variants_menu_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_menu_item_variants_menu_item_id ON public.menu_item_variants USING btree (menu_item_id);

--
-- Name: ix_menu_items_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_menu_items_category_id ON public.menu_items USING btree (category_id);

--
-- Name: ix_menu_items_meal_types; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_menu_items_meal_types ON public.menu_items USING gin (meal_types);

--
-- Name: ix_menu_items_restaurant_available; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_menu_items_restaurant_available ON public.menu_items USING btree (restaurant_id, is_available);

--
-- Name: ix_menu_items_tags; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_menu_items_tags ON public.menu_items USING gin (tags);

--
-- Name: ix_notifications_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_notifications_created_at ON public.notifications USING btree (created_at);

--
-- Name: ix_notifications_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_notifications_user_id ON public.notifications USING btree (user_id);

--
-- Name: ix_order_items_menu_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_order_items_menu_item_id ON public.order_items USING btree (menu_item_id);

--
-- Name: ix_order_items_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_order_items_order_id ON public.order_items USING btree (order_id);

--
-- Name: ix_order_status_history_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_order_status_history_order_id ON public.order_status_history USING btree (order_id);

--
-- Name: ix_orders_restaurant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_orders_restaurant_id ON public.orders USING btree (restaurant_id);

--
-- Name: ix_orders_status_placed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_orders_status_placed ON public.orders USING btree (status, placed_at);

--
-- Name: ix_orders_user_placed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_orders_user_placed ON public.orders USING btree (user_id, placed_at);

--
-- Name: ix_password_reset_tokens_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_password_reset_tokens_user_id ON public.password_reset_tokens USING btree (user_id);

--
-- Name: ix_user_sessions_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_user_sessions_user_id ON public.user_sessions USING btree (user_id);

--
-- Name: uq_addresses_one_default_per_user; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_addresses_one_default_per_user ON public.addresses USING btree (user_id) WHERE is_default;

--
-- Name: uq_menu_item_variants_one_default; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_menu_item_variants_one_default ON public.menu_item_variants USING btree (menu_item_id) WHERE is_default;

--
-- Name: uq_users_email_lower; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_users_email_lower ON public.users USING btree (lower((email)::text));

--
-- Name: add_ons fk_add_ons_restaurant_id_restaurants; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.add_ons
    ADD CONSTRAINT fk_add_ons_restaurant_id_restaurants FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

--
-- Name: addresses fk_addresses_user_id_users; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT fk_addresses_user_id_users FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

--
-- Name: cart_item_add_ons fk_cart_item_add_ons_add_on_id_add_ons; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cart_item_add_ons
    ADD CONSTRAINT fk_cart_item_add_ons_add_on_id_add_ons FOREIGN KEY (add_on_id) REFERENCES public.add_ons(id) ON DELETE CASCADE;

--
-- Name: cart_item_add_ons fk_cart_item_add_ons_cart_item_id_cart_items; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cart_item_add_ons
    ADD CONSTRAINT fk_cart_item_add_ons_cart_item_id_cart_items FOREIGN KEY (cart_item_id) REFERENCES public.cart_items(id) ON DELETE CASCADE;

--
-- Name: cart_items fk_cart_items_cart_id_carts; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cart_items
    ADD CONSTRAINT fk_cart_items_cart_id_carts FOREIGN KEY (cart_id) REFERENCES public.carts(id) ON DELETE CASCADE;

--
-- Name: cart_items fk_cart_items_menu_item_id_menu_items; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cart_items
    ADD CONSTRAINT fk_cart_items_menu_item_id_menu_items FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id) ON DELETE CASCADE;

--
-- Name: cart_items fk_cart_items_variant_id_menu_item_variants; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cart_items
    ADD CONSTRAINT fk_cart_items_variant_id_menu_item_variants FOREIGN KEY (variant_id) REFERENCES public.menu_item_variants(id) ON DELETE SET NULL;

--
-- Name: carts fk_carts_offer_id_offers; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carts
    ADD CONSTRAINT fk_carts_offer_id_offers FOREIGN KEY (offer_id) REFERENCES public.offers(id) ON DELETE SET NULL;

--
-- Name: carts fk_carts_restaurant_id_restaurants; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carts
    ADD CONSTRAINT fk_carts_restaurant_id_restaurants FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE SET NULL;

--
-- Name: carts fk_carts_user_id_users; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carts
    ADD CONSTRAINT fk_carts_user_id_users FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

--
-- Name: favorite_menu_items fk_favorite_menu_items_menu_item_id_menu_items; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorite_menu_items
    ADD CONSTRAINT fk_favorite_menu_items_menu_item_id_menu_items FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id) ON DELETE CASCADE;

--
-- Name: favorite_menu_items fk_favorite_menu_items_user_id_users; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorite_menu_items
    ADD CONSTRAINT fk_favorite_menu_items_user_id_users FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

--
-- Name: favorite_restaurants fk_favorite_restaurants_restaurant_id_restaurants; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorite_restaurants
    ADD CONSTRAINT fk_favorite_restaurants_restaurant_id_restaurants FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

--
-- Name: favorite_restaurants fk_favorite_restaurants_user_id_users; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorite_restaurants
    ADD CONSTRAINT fk_favorite_restaurants_user_id_users FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

--
-- Name: media_assets fk_media_assets_uploaded_by_id_users; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_assets
    ADD CONSTRAINT fk_media_assets_uploaded_by_id_users FOREIGN KEY (uploaded_by_id) REFERENCES public.users(id) ON DELETE SET NULL;

--
-- Name: menu_item_variants fk_menu_item_variants_menu_item_id_menu_items; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_item_variants
    ADD CONSTRAINT fk_menu_item_variants_menu_item_id_menu_items FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id) ON DELETE CASCADE;

--
-- Name: menu_items fk_menu_items_category_id_categories; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_items
    ADD CONSTRAINT fk_menu_items_category_id_categories FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE SET NULL;

--
-- Name: menu_items fk_menu_items_restaurant_id_restaurants; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_items
    ADD CONSTRAINT fk_menu_items_restaurant_id_restaurants FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

--
-- Name: notifications fk_notifications_user_id_users; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT fk_notifications_user_id_users FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

--
-- Name: order_items fk_order_items_menu_item_id_menu_items; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT fk_order_items_menu_item_id_menu_items FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id) ON DELETE SET NULL;

--
-- Name: order_items fk_order_items_order_id_orders; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT fk_order_items_order_id_orders FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;

--
-- Name: order_status_history fk_order_status_history_changed_by_user_id_users; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_status_history
    ADD CONSTRAINT fk_order_status_history_changed_by_user_id_users FOREIGN KEY (changed_by_user_id) REFERENCES public.users(id) ON DELETE SET NULL;

--
-- Name: order_status_history fk_order_status_history_order_id_orders; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_status_history
    ADD CONSTRAINT fk_order_status_history_order_id_orders FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;

--
-- Name: orders fk_orders_offer_id_offers; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT fk_orders_offer_id_offers FOREIGN KEY (offer_id) REFERENCES public.offers(id) ON DELETE SET NULL;

--
-- Name: orders fk_orders_restaurant_id_restaurants; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT fk_orders_restaurant_id_restaurants FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE RESTRICT;

--
-- Name: orders fk_orders_user_id_users; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT fk_orders_user_id_users FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;

--
-- Name: password_reset_tokens fk_password_reset_tokens_user_id_users; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_reset_tokens
    ADD CONSTRAINT fk_password_reset_tokens_user_id_users FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

--
-- Name: user_sessions fk_user_sessions_user_id_users; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT fk_user_sessions_user_id_users FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

--
-- Name: users fk_users_selected_address_id_addresses; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_users_selected_address_id_addresses FOREIGN KEY (selected_address_id) REFERENCES public.addresses(id) ON DELETE SET NULL;

--
-- PostgreSQL database dump complete
--
